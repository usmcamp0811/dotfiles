{
  lib,
  config,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.niks3-auto-upload;

  # Must exactly match the systemd service name defined by upstream's
  # niks3-auto-upload module: nixos-vault-service only "infects" (adds the
  # sidecar dependency + shared PrivateTmp namespace to) a systemd unit whose
  # name matches the vault-agent service name.
  vaultAgentName = "niks3-auto-upload";

  # Where nixos-vault-service renders `secrets.file.files."auth-token"`
  # (its `${secretFilesRoot}${name}` convention, secretFilesRoot =
  # "/tmp/detsys-vault/"). Kept as a plain string constant for the same
  # reason as in fmf.services.niks3: looking it up via
  # config.fmf.services.vault-agent.services.<name>... would force an
  # attribute that only exists once this module's own config block below
  # registers it.
  vaultTokenFilePath = "/tmp/detsys-vault/auth-token";

  usesVault = cfg.authTokenFile == null;

  resolvedAuthTokenFile =
    if usesVault
    then vaultTokenFilePath
    else cfg.authTokenFile;

  vaultSecretTemplate = path: kvVersion: field: ''
    {{ with secret "${path}" }}{{ if eq "${kvVersion}" "v1" }}{{ .Data.${field} }}{{ else }}{{ .Data.data.${field} }}{{ end }}{{ end }}
  '';
in {
  imports = [inputs.niks3.nixosModules.niks3-auto-upload];

  options.fmf.services.niks3-auto-upload = with types; {
    enable =
      mkBoolOpt false
      ''
        Automatically upload every locally built store path to a niks3 binary
        cache server via Nix's post-build-hook (a thin, Vault-fed wrapper
        around upstream's services.niks3-auto-upload).
      '';

    serverUrl =
      mkOpt (nullOr str) null
      ''URL of the niks3 server to upload to (e.g. "http://10.8.0.176:5751"). Required.'';

    authTokenFile =
      mkOpt (nullOr path) null
      "Explicit path to a file holding the niks3 API token, bypassing Vault.";

    debug =
      mkBoolOpt false
      "Enable debug logging in the upload daemon.";

    settings =
      mkOpt attrs {}
      ''
        Raw services.niks3-auto-upload configuration merged on top of what
        this module generates. Escape hatch for options not curated here,
        e.g. batchSize, maxConcurrentUploads, idleExitTimeout or mtls.
      '';

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id.";

    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id.";

    # Defaults deliberately point at the SAME Vault secret/field the niks3
    # server itself (fmf.services.niks3) reads its API token from: niks3 has
    # a single static API token, so clients authenticate with that one.
    vault-path =
      mkOpt str "secret/campground/niks3"
      "Vault KV path holding the niks3 API token.";

    vault-field =
      mkOpt str "api_token"
      "Field within vault-path that holds the niks3 API token.";

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
        assertion = cfg.serverUrl != null;
        message = "fmf.services.niks3-auto-upload.serverUrl must be set when fmf.services.niks3-auto-upload.enable = true.";
      }
    ];

    services.niks3-auto-upload = mkMerge [
      {
        enable = true;
        serverUrl = cfg.serverUrl;
        authTokenFile = resolvedAuthTokenFile;
        debug = cfg.debug;
      }
      cfg.settings
    ];

    fmf.services.vault-agent.services.${vaultAgentName} = mkIf usesVault {
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

      # `secrets.file` (not `secrets.environment`): upstream's daemon takes the
      # token as a *file path* (--auth-token-path). The upload daemon is
      # socket-activated and exits when idle, and its client re-reads and
      # trims this file itself, so a rotated token is picked up without
      # restarting anything -- hence change-action = "none".
      secrets.file = {
        change-action = "none";

        files."auth-token".text =
          vaultSecretTemplate cfg.vault-path cfg.kvVersion cfg.vault-field;
      };
    };
  };
}
