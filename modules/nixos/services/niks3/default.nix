{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.niks3;

  vaultAgentName = "niks3";

  # Path to a Vault-templated *secret file* (as opposed to an
  # EnvironmentFile) rendered by the niks3 vault-agent service below.
  # This mirrors nixos-vault-service's own
  # `${secretFilesRoot}${name}` convention (secretFilesRoot =
  # "/tmp/detsys-vault/") as a plain string constant, for the same
  # reason envPath-style helpers elsewhere in this codebase are plain
  # constants rather than looking up `config.fmf.services.vault-agent...`:
  # that attribute only exists once this module's own `config` block
  # below actually registers it -- something NixOS's module system can
  # force while evaluating unrelated options, even when this module is
  # otherwise disabled.
  #
  # Deliberately *not* using `secrets.environment.templates`
  # (`/run/keys/environment/...`) here: those files are hardcoded by
  # nixos-vault-service to mode 0400 owned by whatever user renders them
  # (effectively root), with no way to override -- fine for
  # EnvironmentFile= consumption (systemd/PID1 reads it as root before
  # dropping privileges), but useless for niks3-server, which opens
  # these paths itself as the unprivileged `niks3` user via CLI
  # arguments. `secrets.file.files` instead `chown`s the rendered file
  # to the *consuming unit's own* configured User/Group (niks3:niks3
  # here) after each render, which is what actually makes it readable
  # by the very process that needs to open it.
  vaultSecretFilePath = name: "/tmp/detsys-vault/${name}";

  vaultSecretTemplate = path: kvVersion: field: ''
    {{ with secret "${path}" }}{{ if eq "${kvVersion}" "v1" }}{{ .Data.${field} }}{{ else }}{{ .Data.data.${field} }}{{ end }}{{ end }}
  '';

  # Where niks3's S3 credentials live in Vault: the same path
  # fmf.services.garage.buckets.niks3 reads from when backend = "garage"
  # (a single source of truth -- see the wiring below), or a dedicated
  # niks3 path for backend = "s3".
  s3VaultPath =
    if cfg.backend == "garage"
    then cfg.garage.vaultPath
    else cfg.s3.vaultPath;

  # Whether niks3's S3 credentials should be sourced from Vault at all:
  # not needed with IAM auth, and skipped if the operator points
  # directly at pre-existing key files.
  usesVaultS3Creds =
    !cfg.s3.useIAM
    && cfg.s3.accessKeyFile == null
    && cfg.s3.secretKeyFile == null;

  garagePort =
    last (splitString ":" config.fmf.services.garage.s3ApiBindAddress);

  resolvedEndpoint =
    if cfg.backend == "garage"
    then "${cfg.garage.host}:${garagePort}"
    else cfg.s3.endpoint;

  resolvedUseSSL =
    if cfg.s3.useSSL != null
    then cfg.s3.useSSL
    else cfg.backend == "s3";

  resolvedRegion =
    if cfg.s3.region != null
    then cfg.s3.region
    else if cfg.backend == "garage"
    then config.fmf.services.garage.region
    else "us-east-1";

  resolvedBucketLookup =
    if cfg.s3.bucketLookup != null
    then cfg.s3.bucketLookup
    else if cfg.backend == "garage"
    then "path"
    else "auto";

  resolvedAccessKeyFile =
    if cfg.s3.accessKeyFile != null
    then cfg.s3.accessKeyFile
    else if usesVaultS3Creds
    then vaultSecretFilePath "s3-access-key-id"
    else null;

  resolvedSecretKeyFile =
    if cfg.s3.secretKeyFile != null
    then cfg.s3.secretKeyFile
    else if usesVaultS3Creds
    then vaultSecretFilePath "s3-secret-access-key"
    else null;

  resolvedApiTokenFile =
    if cfg.apiTokenFile != null
    then cfg.apiTokenFile
    else vaultSecretFilePath "api-token";

  resolvedSignKeyFiles =
    if cfg.signKeyFiles != []
    then cfg.signKeyFiles
    else optional cfg.signKey.enable (vaultSecretFilePath "sign-key");
in {
  imports = [inputs.niks3.nixosModules.niks3];

  options.fmf.services.niks3 = with types; {
    enable =
      mkBoolOpt false
      "Enable niks3, an S3-backed Nix binary cache server with garbage collection.";

    httpAddr =
      mkOpt str "127.0.0.1:5751"
      "HTTP address niks3-server listens on.";

    bucket =
      mkOpt str "niks3"
      "S3 bucket used to store the binary cache.";

    backend =
      mkOpt (enum ["garage" "s3"]) "garage"
      ''
        Where the S3 bucket used by niks3 lives:
        - "garage": a co-located fmf.services.garage instance. A bucket
          and API key are idempotently provisioned for niks3 via
          fmf.services.garage.buckets.niks3 (see fmf.services.garage's
          layout/buckets options for the bootstrap logic).
        - "s3": any external S3-compatible provider (AWS S3, Cloudflare
          R2, Backblaze B2, MinIO, a remote Garage cluster, etc). Set
          s3.endpoint (and usually s3.region).
      '';

    garage = {
      host =
        mkOpt str "127.0.0.1"
        ''
          Host (or host:port) of the Garage S3 API to use when
          backend = "garage". Defaults to the local node's S3 API port
          (fmf.services.garage.s3ApiBindAddress).
        '';

      keyName =
        mkOpt str "niks3"
        "Name of the Garage API key created for niks3.";

      vaultPath =
        mkOpt str "secret/campground/garage/buckets/niks3"
        ''
          Vault KV path holding access_key_id/secret_access_key for
          niks3's Garage key. Shared with the
          fmf.services.garage.buckets.niks3 entry this module creates --
          both read the same Vault secret so there is a single source of
          truth for this key's credentials.
        '';
    };

    s3 = {
      endpoint =
        mkOpt (nullOr str) null
        ''
          S3 endpoint (e.g. "s3.amazonaws.com" or
          "<accountid>.r2.cloudflarestorage.com"). Required when
          backend = "s3".
        '';

      region =
        mkOpt (nullOr str) null
        ''
          S3 region. Defaults to fmf.services.garage.region for
          backend = "garage", or "us-east-1" for backend = "s3". Use
          "auto" for Cloudflare R2.
        '';

      useSSL =
        mkOpt (nullOr bool) null
        ''
          Use SSL/TLS for S3 connections. Defaults to false for
          backend = "garage" (plain local HTTP), true for
          backend = "s3".
        '';

      bucketLookup =
        mkOpt (nullOr (enum ["auto" "dns" "path"])) null
        ''
          S3 bucket addressing style. Defaults to "path" for
          backend = "garage" (Garage doesn't do virtual-hosted style
          unless s3RootDomain is configured), "auto" for backend = "s3".
        '';

      publicUrl =
        mkOpt (nullOr str) null
        "Externally reachable S3 base URL used in presigned URLs, if different from endpoint.";

      useIAM =
        mkBoolOpt false
        ''
          Use IAM credentials (IRSA / EC2 instance profile / ECS task
          role) instead of static keys. Only meaningful for
          backend = "s3"; cannot be combined with accessKeyFile/
          secretKeyFile.
        '';

      accessKeyFile =
        mkOpt (nullOr path) null
        "Explicit path to an access key file, bypassing Vault entirely.";

      secretKeyFile =
        mkOpt (nullOr path) null
        "Explicit path to a secret key file, bypassing Vault entirely.";

      vaultPath =
        mkOpt str "secret/campground/niks3/s3"
        ''
          Vault KV path holding access_key_id/secret_access_key. Only
          used when backend = "s3" and useIAM/accessKeyFile/
          secretKeyFile are all unset.
        '';
    };

    database = {
      createLocally =
        mkBoolOpt true
        "Create and use a local PostgreSQL database for niks3.";

      connectionString =
        mkOpt (nullOr str) null
        "Override the Postgres connection string used by niks3.";
    };

    apiTokenFile =
      mkOpt (nullOr path) null
      "Explicit path to the niks3 API token file, bypassing Vault.";

    signKeyFiles =
      mkOpt (listOf path) []
      "Explicit paths to narinfo signing key files, bypassing Vault. Takes precedence over signKey.enable.";

    signKey.enable =
      mkBoolOpt true
      ''
        Source a single Ed25519 narinfo signing key from Vault (field
        "sign_key" at vault-path, formatted as "name:base64key" -- the
        same format produced by `nix key generate-secret`).
      '';

    cacheUrl =
      mkOpt (nullOr str) null
      "Public URL where the binary cache is accessible (used for the generated landing page).";

    serverUrl =
      mkOpt (nullOr str) null
      "Public URL of the niks3 server itself, if different from cacheUrl.";

    maxNarSize =
      mkOpt (nullOr str) null
      ''Maximum uncompressed NAR size accepted for upload (e.g. "2G").'';

    priority =
      mkOpt int 30
      "Priority advertised in nix-cache-info. Lower is preferred by Nix.";

    openFirewall =
      mkBoolOpt false
      "Open httpAddr's port in the firewall. Usually left disabled in favor of nginx.enable.";

    nginx = {
      enable = mkBoolOpt false "Front niks3 with an nginx reverse proxy + ACME.";

      domain =
        mkOpt (nullOr str) null
        "Domain name for the nginx virtual host. Required when nginx.enable is true.";
    };

    gc = {
      enable = mkBoolOpt true "Enable niks3's periodic garbage collection timer.";

      olderThan =
        mkOpt str "720h"
        "How old closures must be before being garbage collected (Go duration format).";

      schedule =
        mkOpt str "daily"
        "systemd OnCalendar schedule for garbage collection.";
    };

    settings =
      mkOpt attrs {}
      ''
        Raw services.niks3 configuration merged on top of the settings
        this module generates. Escape hatch for options not curated
        here, e.g. oidc.providers, nginx.mtls, or readProxy.
      '';

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id.";

    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id.";

    vault-path =
      mkOpt str "secret/campground/niks3"
      "Vault KV path holding niks3's own secrets: api_token (and sign_key, if signKey.enable).";

    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV store version.";
    };

    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "Vault server address.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.backend != "s3" || cfg.s3.endpoint != null;
        message = ''fmf.services.niks3.s3.endpoint must be set when fmf.services.niks3.backend = "s3".'';
      }
      {
        assertion = !cfg.nginx.enable || cfg.nginx.domain != null;
        message = "fmf.services.niks3.nginx.domain must be set when fmf.services.niks3.nginx.enable = true.";
      }
      {
        assertion = !(cfg.s3.useIAM && (cfg.s3.accessKeyFile != null || cfg.s3.secretKeyFile != null));
        message = "fmf.services.niks3.s3.useIAM cannot be combined with s3.accessKeyFile / s3.secretKeyFile.";
      }
    ];

    # Idempotently provision a Garage bucket + key for niks3 when it is
    # backed by a co-located Garage instance. The actual bootstrap logic
    # (cluster layout, bucket, key, and permissions, all created
    # idempotently at boot) lives in fmf.services.garage.
    fmf.services.garage.buckets = mkIf (cfg.backend == "garage") {
      niks3 = {
        bucketName = cfg.bucket;
        keyName = cfg.garage.keyName;
        vault-path = cfg.garage.vaultPath;
        kvVersion = cfg.kvVersion;
        permissions = {
          read = true;
          write = true;
          owner = false;
        };
      };
    };

    services.niks3 = mkMerge [
      {
        enable = true;
        httpAddr = cfg.httpAddr;
        priority = cfg.priority;

        database =
          {inherit (cfg.database) createLocally;}
          // optionalAttrs (cfg.database.connectionString != null) {
            connectionString = cfg.database.connectionString;
          };

        s3 =
          {
            endpoint = resolvedEndpoint;
            bucket = cfg.bucket;
            region = resolvedRegion;
            useSSL = resolvedUseSSL;
            bucketLookup = resolvedBucketLookup;
            useIAM = cfg.s3.useIAM;
          }
          // optionalAttrs (cfg.s3.publicUrl != null) {publicUrl = cfg.s3.publicUrl;}
          // optionalAttrs (resolvedAccessKeyFile != null) {accessKeyFile = resolvedAccessKeyFile;}
          // optionalAttrs (resolvedSecretKeyFile != null) {secretKeyFile = resolvedSecretKeyFile;};

        apiTokenFile = resolvedApiTokenFile;
        signKeyFiles = resolvedSignKeyFiles;

        gc = {
          inherit (cfg.gc) enable;
          olderThan = cfg.gc.olderThan;
          schedule = cfg.gc.schedule;
        };
      }
      (optionalAttrs (cfg.cacheUrl != null) {cacheUrl = cfg.cacheUrl;})
      (optionalAttrs (cfg.serverUrl != null) {serverUrl = cfg.serverUrl;})
      (optionalAttrs (cfg.maxNarSize != null) {maxNarSize = cfg.maxNarSize;})
      (optionalAttrs cfg.nginx.enable {
        nginx = {
          enable = true;
          domain = cfg.nginx.domain;
        };
      })
      cfg.settings
    ];

    networking.firewall.allowedTCPPorts =
      optionals cfg.openFirewall [
        (toInt (last (splitString ":" cfg.httpAddr)))
      ];

    # niks3-gc.service isn't the unit nixos-vault-service auto-infects
    # (that only happens for a systemd service whose name exactly
    # matches the vault-agent service name, "niks3" here), but it reads
    # the same Vault-sourced apiTokenFile as niks3.service. Since that
    # secret file is rendered into the "niks3" vault-agent sidecar's own
    # PrivateTmp (see vaultSecretFilePath above), niks3-gc needs to
    # explicitly join *that same* sidecar's mount namespace itself to
    # see it -- otherwise it gets its own empty, unrelated private /tmp.
    systemd.services.niks3-gc = mkIf cfg.gc.enable {
      after = ["detsys-vaultAgent-${vaultAgentName}.service"];
      unitConfig.JoinsNamespaceOf = "detsys-vaultAgent-${vaultAgentName}.service";
    };

    fmf.services.vault-agent.services.${vaultAgentName} = {
      settings = {
        vault.address = cfg.vault-address;

        auto_auth = {
          method = [
            {
              type = "approle";

              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };

      # `secrets.file.files` (not `secrets.environment.templates`):
      # these are consumed as file *paths* by niks3-server's own CLI
      # args, opened directly by the unprivileged `niks3` user, so they
      # need to be `chown`ed to that user -- which is exactly what
      # `secrets.file.files` does (to the target unit's own User/Group)
      # and `secrets.environment.templates` deliberately cannot (hardcoded
      # to mode 0400, effectively root-only, since it exists to feed
      # systemd's own EnvironmentFile= loading instead).
      secrets.file = {
        change-action = "restart";

        files =
          {
            "api-token".text = vaultSecretTemplate cfg.vault-path cfg.kvVersion "api_token";
          }
          // optionalAttrs cfg.signKey.enable {
            "sign-key".text = vaultSecretTemplate cfg.vault-path cfg.kvVersion "sign_key";
          }
          // optionalAttrs usesVaultS3Creds {
            "s3-access-key-id".text = vaultSecretTemplate s3VaultPath cfg.kvVersion "access_key_id";
            "s3-secret-access-key".text = vaultSecretTemplate s3VaultPath cfg.kvVersion "secret_access_key";
          };
      };
    };
  };
}
