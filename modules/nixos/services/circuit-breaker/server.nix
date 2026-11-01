# Circuit Breaker server: the upstream "mono" OCI image (nginx, FastAPI, embedded
# PostgreSQL/TimescaleDB, Redis, NATS in one container), pinned by digest.
#
# Why a container and not a native package: upstream ships a ~1 GB application
# tree built by its own pipeline (python-build-standalone, Timescale, NATS, ...).
# Re-packaging that in Nix would be a fork. The container is what upstream
# supports and tests; we pin it by digest, run it with least privilege, and keep
# all state in one host directory.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.circuit-breaker;
  srv = cfg.server;
  backend = config.virtualisation.oci-containers.backend;
  runtime =
    if backend == "docker"
    then config.virtualisation.docker.package
    else config.virtualisation.podman.package;
  rt = "${runtime}/bin/${backend}";
  unit = "${backend}-circuit-breaker";
  containerName = "circuit-breaker";

  secretsDir = "${srv.dataDir}/secrets";
  generatedEnv = "${secretsDir}/server.env";
  vaultFile = "/tmp/detsys-vault/circuit-breaker.env";
  # Must differ from the container unit's own RuntimeDirectory (oci-containers names it
  # after the container): systemd deletes that directory whenever the container unit
  # restarts, which would remove the secrets mid-flight.
  secretsRunDir = "circuit-breaker-secrets";
  runtimeEnv = "/run/${secretsRunDir}/server.env";
  envFile =
    if srv.secrets.vault.enable
    then runtimeEnv
    else if srv.secrets.environmentFile != null
    then srv.secrets.environmentFile
    else runtimeEnv;

  # Names the container needs; they are provided only through the env file.
  secretVars = ["CB_DB_PASSWORD" "CB_VAULT_KEY" "CB_JWT_SECRET" "NATS_AUTH_TOKEN"];

  # podman copies the image's existing directory contents into every --tmpfs by default
  # ("tmpcopyup"); the image ships 39 MB under /var/lib/postgresql, so a 10 MB tmpfs fails
  # with ENOSPC. Docker never copies up, so only podman needs the opt-out.
  tmpfsOptions = map (m: "--tmpfs=${m}${optionalString (backend == "podman") ",notmpcopyup"}") [
    "/tmp:size=100M"
    "/run:size=10M"
    "/var/log:size=50M"
    "/var/lib/nginx:size=10M"
    "/var/lib/postgresql:size=10M"
  ];

  environment =
    {
      CB_ALLOW_DIRECT_EGRESS = boolToString srv.egress.allowDirect;
      CB_AIRGAP = boolToString srv.egress.airgap;
      CB_UPDATE_CHECK = boolToString srv.updateCheck;
      CB_TRUSTED_PROXY_CIDRS = concatStringsSep "," srv.trustedProxyCidrs;
      CB_ALLOW_DEGRADED_DEPENDENCIES = "false";
    }
    // optionalAttrs (srv.egress.proxyUrl != null) {CB_EGRESS_PROXY_URL = srv.egress.proxyUrl;}
    // srv.extraEnvironment;

  # Where the local reconciler and helpers reach the API.
  apiHost =
    if srv.listenAddress == "0.0.0.0" || srv.listenAddress == "::"
    then "127.0.0.1"
    else srv.listenAddress;

  # Exec into the container with the database URL the entrypoint would compute.
  admin = pkgs.writeShellApplication {
    name = "circuit-breaker-admin";
    runtimeInputs = [runtime pkgs.coreutils pkgs.jq pkgs.gnugrep pkgs.curl];
    text = ''
      cname=${containerName}
      cb_exec() {
        ${backend} exec -i -e CB_DATA_DIR=/data "$cname" sh -c '
          CB_DB_URL="$(python3 -c "import os; from urllib.parse import quote; print(\"postgresql://breaker:%s@127.0.0.1:5432/circuitbreaker\" % quote(os.environ[\"CB_DB_PASSWORD\"], safe=\"\"))")"
          export CB_DB_URL
          exec python -m app.cli "$@"' sh "$@"
      }
      usage() {
        cat <<'EOF'
      circuit-breaker-admin <command>

        status                 container + readiness state
        setup-token            print the one-time first-run setup token
        mint-sync-token        create (or rotate) the flake-sync API token and store it
        snapshot               create a full-state snapshot (contains the vault key!)
        cli <args...>          run the upstream admin CLI (python -m app.cli ...)
      EOF
      }
      cmd="''${1:-}"; shift || true
      case "$cmd" in
        status)
          ${backend} ps --filter "name=^$cname$" --format '{{.Names}}  {{.Status}}' || true
          curl -fsS --max-time 5 http://127.0.0.1:${toString srv.httpProbePort}/api/v1/readyz && echo
          ;;
        setup-token)
          # The token is issued lazily on the first bootstrap-status request.
          status="$(curl -ksS --max-time 10 "https://${apiHost}:${toString srv.port}/api/v1/bootstrap/status" || true)"
          if [ "$(printf '%s' "$status" | jq -r '.needs_bootstrap // empty')" != "true" ]; then
            echo "first-run setup is already complete (or the server is not answering); no setup token to print." >&2
            exit 1
          fi
          echo "Printing the one-time setup token; do not paste it into logs." >&2
          ${backend} exec "$cname" cat /data/bootstrap-setup-token
          ;;
        mint-sync-token)
          token_file=${cfg.flakeSync.tokenFile}
          label=nix-flake-sync
          install -d -m 0700 "$(dirname "$token_file")"
          existing="$(cb_exec token list --json | jq -r --arg l "$label" '[.[] | select(.label == $l)] | first | .id // empty')"
          umask 077
          tmp="$(mktemp "$token_file.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          if [ -n "$existing" ]; then
            echo "token '$label' exists (id $existing); rotating its secret" >&2
            cb_exec token rotate "$existing" --json | jq -r .token > "$tmp"
          else
            cb_exec token create --label "$label" --scopes 'read:*' 'write:*' \
              ${
        if cfg.flakeSync.token.expiresInDays == null
        then "--never-expires"
        else "--expires-in-days ${toString cfg.flakeSync.token.expiresInDays}"
      } --json | jq -r .token > "$tmp"
          fi
          test -s "$tmp"
          chmod 0400 "$tmp"
          mv -f "$tmp" "$token_file"
          trap - EXIT
          echo "wrote $token_file" >&2
          ;;
        snapshot)
          cb_exec snapshot create
          ;;
        cli)
          cb_exec "$@"
          ;;
        *) usage; exit 2 ;;
      esac
    '';
  };

  generateSecrets = pkgs.writeShellScript "circuit-breaker-generate-secrets" ''
    set -euo pipefail
    umask 077
    install -d -m 0700 ${secretsDir}
    if [ -s ${generatedEnv} ]; then
      exit 0   # never regenerate: the database and vault are keyed to these values
    fi
    tmp="$(mktemp ${secretsDir}/.server.env.XXXXXX)"
    {
      echo "CB_DB_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -hex 24)"
      # Fernet key: url-safe base64 of 32 random bytes
      echo "CB_VAULT_KEY=$(${pkgs.openssl}/bin/openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
      echo "CB_JWT_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)"
      echo "NATS_AUTH_TOKEN=$(${pkgs.openssl}/bin/openssl rand -hex 32)"
    } > "$tmp"
    chmod 0400 "$tmp"
    mv "$tmp" ${generatedEnv}
  '';

  # Generates (optionally) and copies the chosen secret source to a root-only
  # runtime file the container reads. One script = one ExecStart, which is what the
  # vault-agent wrapper expects.
  stageEnv = pkgs.writeShellScript "circuit-breaker-stage-env" ''
    set -euo pipefail
    umask 077
    ${optionalString srv.secrets.generate "${generateSecrets}"}
    src=${
      if srv.secrets.vault.enable
      then vaultFile
      else if srv.secrets.environmentFile != null
      then srv.secrets.environmentFile
      else generatedEnv
    }
    if [ ! -s "$src" ]; then
      echo "circuit-breaker: secret environment file $src is missing or empty" >&2
      exit 1
    fi
    for v in ${concatStringsSep " " secretVars}; do
      if ! ${pkgs.gnugrep}/bin/grep -q "^$v=." "$src"; then
        echo "circuit-breaker: $src does not define $v" >&2
        exit 1
      fi
    done
    install -m 0400 -o root -g root "$src" ${runtimeEnv}
  '';

  tlsInstall = pkgs.writeShellScript "circuit-breaker-install-tls" ''
    set -euo pipefail
    umask 077
    install -d -m 0700 ${srv.dataDir}/data/tls
    install -m 0644 ${srv.tls.certFile} ${srv.dataDir}/data/tls/fullchain.pem
    install -m 0600 ${srv.tls.keyFile} ${srv.dataDir}/data/tls/privkey.pem
  '';

  readyScript = pkgs.writeShellScript "circuit-breaker-wait-ready" ''
    set -euo pipefail
    for i in $(seq 1 120); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 4 http://127.0.0.1:${toString srv.httpProbePort}/api/v1/readyz >/dev/null 2>&1; then
        exit 0
      fi
      sleep 5
    done
    echo "circuit-breaker did not become ready within 10 minutes" >&2
    exit 1
  '';
in {
  options.fmf.services.circuit-breaker.server = {
    enable = mkBoolOpt false "Run the Circuit Breaker server (OCI mono image) on this host.";

    image = mkOpt types.str "ghcr.io/blkleg/circuitbreaker@sha256:a6ae4573294642a7bdf1912d4060b6a75e7b3960dc44bea7b142096946a20c3a" ''
      Container image, pinned by digest. This is upstream release 0.4.6
      (multi-arch index digest); `ghcr.io/blkleg/circuitbreaker:0.4.6` resolves to it.
      The reconciler is verified against that API version. To upgrade, change
      this digest and review docs/CIRCUIT-BREAKER.md (Upgrade and rollback).
      Ignored when `imageFile` is set.
    '';
    imageFile = mkOpt (types.nullOr types.package) null ''
      An image archive built by `dockerTools.pullImage { imageDigest = ...; sha256 = ...; }`.
      It is loaded instead of pulled (offline / reproducible deployments, NixOS tests);
      the content is pinned by the fixed-output hash, and the container runs
      `<imageName>:<imageTag>` as the nixpkgs oci-containers module requires.
    '';
    dataDir = mkOpt types.str "/var/lib/circuit-breaker" ''
      Persistent state root. `<dataDir>/data` is mounted at /data in the container
      (database, uploads, TLS material, vault key file); `<dataDir>/secrets` holds
      generated secrets. The directory is root-only (0700): inside the container the
      application runs as uid 1000, which would otherwise be a login user on the host.
    '';
    listenAddress = mkOpt types.str "127.0.0.1" "Host address the HTTPS port is published on. Use the LAN address (not 0.0.0.0) when a remote reverse proxy forwards to it.";
    port = mkOpt types.port 8443 "Host port for the HTTPS UI/API (container 8443).";
    httpProbePort = mkOpt types.port 8080 "Loopback-only host port for the plain-HTTP health probes (container 8080; everything else redirects to HTTPS).";
    domain = mkOpt (types.nullOr types.str) null ''
      Public host name (e.g. topology.lan.example.com). Used for documentation, agent
      URLs and assertions; set the same value as "App URL" in Settings -> Connectivity.
    '';
    openFirewall = mkBoolOpt false "Open the HTTPS port in the host firewall.";
    trustedProxyCidrs = mkOpt (types.listOf types.str) ["127.0.0.1/32" "::1/128"] ''
      Source ranges whose X-Forwarded-* headers are trusted (CB_TRUSTED_PROXY_CIDRS).
      Add your reverse proxy's address, otherwise every client appears to come from
      the proxy and shares one rate-limit bucket.
    '';
    updateCheck = mkBoolOpt false "Allow the daily GitHub release check (CB_UPDATE_CHECK). Off: versions are managed by Nix.";
    extraEnvironment = mkOpt (types.attrsOf types.str) {} "Additional non-secret environment variables.";

    tls = {
      certFile = mkOpt (types.nullOr types.str) null "PEM certificate chain to serve (runtime path, e.g. from your ACME/Vault flow). null = upstream generates a self-signed certificate on first start.";
      keyFile = mkOpt (types.nullOr types.str) null "PEM private key matching certFile (runtime path; never a store path).";
    };

    egress = {
      allowDirect = mkBoolOpt true "Allow outbound HTTP without a forward proxy (CB_ALLOW_DIRECT_EGRESS). Upstream refuses to start unless this or proxyUrl is set.";
      proxyUrl = mkOpt (types.nullOr types.str) null "Forward proxy for outbound HTTP (CB_EGRESS_PROXY_URL).";
      airgap = mkBoolOpt false "Block all outbound calls from the application (CB_AIRGAP).";
    };

    resources = {
      memory = mkOpt types.str "2g" "Container memory limit.";
      cpus = mkOpt types.str "2" "Container CPU limit.";
    };

    secrets = {
      environmentFile = mkOpt (types.nullOr types.str) null ''
        Runtime path of an env file defining CB_DB_PASSWORD, CB_VAULT_KEY (Fernet),
        CB_JWT_SECRET and NATS_AUTH_TOKEN. Must not be in the Nix store.
      '';
      generate = mkBoolOpt false ''
        Create the env file once, at first start, under <dataDir>/secrets (0400,
        root). Existing files are never overwritten: the database and the vault are
        keyed to these values. Back this file up together with <dataDir>/data.
      '';
      vault = {
        enable = mkBoolOpt false "Render the env file from HashiCorp Vault with the repository's vault-agent integration.";
        path = mkOpt types.str "secret/campground/circuit-breaker" "KV path holding CB_DB_PASSWORD, CB_VAULT_KEY, CB_JWT_SECRET, NATS_AUTH_TOKEN.";
        kvVersion = mkOption {
          type = types.enum ["v1" "v2"];
          default = "v2";
          description = "KV engine version.";
        };
        address = mkOpt types.str (config.fmf.services.vault-agent.settings.vault.address or "") "Vault address.";
        roleId = mkOpt types.str (config.fmf.services.vault-agent.settings.vault.role-id or "") "Path of the AppRole role-id file.";
        secretId = mkOpt types.str (config.fmf.services.vault-agent.settings.vault.secret-id or "") "Path of the AppRole secret-id file.";
      };
    };

    adminPackage = mkOption {
      type = types.package;
      readOnly = true;
      internal = true;
      default = admin;
      description = "The circuit-breaker-admin helper (used by the provisioning unit).";
    };

    backup = {
      enable = mkBoolOpt false "Create a daily full-state snapshot with the upstream CLI (the application also schedules its own at 02:00).";
      keep = mkOpt types.ints.positive 7 "Snapshots kept in <dataDir>/data/backups by this timer's cleanup.";
    };
  };

  config = mkIf (cfg.enable && srv.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = srv.imageFile != null || hasInfix "@sha256:" srv.image;
          message = "fmf.services.circuit-breaker.server.image must be pinned by digest (…@sha256:…); floating tags are not allowed.";
        }
        {
          assertion = length (filter (x: x) [srv.secrets.generate (srv.secrets.environmentFile != null) srv.secrets.vault.enable]) == 1;
          message = "fmf.services.circuit-breaker.server.secrets: choose exactly one of generate, environmentFile, vault.enable.";
        }
        {
          assertion = srv.secrets.environmentFile == null || !(hasPrefix builtins.storeDir srv.secrets.environmentFile);
          message = "fmf.services.circuit-breaker.server.secrets.environmentFile must not be in the Nix store.";
        }
        {
          assertion = (srv.tls.certFile == null) == (srv.tls.keyFile == null);
          message = "fmf.services.circuit-breaker.server.tls: set both certFile and keyFile, or neither.";
        }
        {
          assertion = all (f: f == null || !(hasPrefix builtins.storeDir f)) [srv.tls.certFile srv.tls.keyFile];
          message = "fmf.services.circuit-breaker.server.tls paths must be runtime paths, not Nix store paths (the key would be world-readable).";
        }
        {
          assertion = all (n: !(elem n secretVars)) (attrNames srv.extraEnvironment);
          message = "fmf.services.circuit-breaker.server.extraEnvironment must not set ${concatStringsSep "/" secretVars}; use server.secrets.";
        }
        {
          assertion = srv.egress.allowDirect || srv.egress.proxyUrl != null || srv.egress.airgap;
          message = "fmf.services.circuit-breaker.server.egress: upstream refuses to start with neither allowDirect nor proxyUrl (airgap also satisfies it).";
        }
        {
          assertion = !srv.secrets.vault.enable || config.fmf.services.vault-agent.enable;
          message = "fmf.services.circuit-breaker.server.secrets.vault.enable requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !(cfg.flakeSync.enable && cfg.flakeSync.tokenFile == null);
          message = "fmf.services.circuit-breaker.flakeSync.tokenFile must be set.";
        }
      ];

      warnings =
        optional (srv.listenAddress == "0.0.0.0")
        "fmf.services.circuit-breaker.server.listenAddress is 0.0.0.0: the management UI/API is exposed on every interface. Prefer a specific LAN address."
        ++ optional (srv.openFirewall && srv.listenAddress == "127.0.0.1")
        "fmf.services.circuit-breaker.server.openFirewall has no effect while listenAddress is 127.0.0.1.";

      virtualisation.oci-containers.containers.${containerName} = {
        image =
          if srv.imageFile != null
          then "${srv.imageFile.imageName}:${srv.imageFile.imageTag}"
          else srv.image;
        imageFile = srv.imageFile;
        autoStart = true;
        ports = [
          "${srv.listenAddress}:${toString srv.port}:8443"
          "127.0.0.1:${toString srv.httpProbePort}:8080"
        ];
        volumes = ["${srv.dataDir}/data:/data"];
        environment = environment;
        environmentFiles = [envFile];
        capabilities = {
          # The entrypoint starts as root to fix volume ownership, then supervisord
          # drops each process to the unprivileged `breaker` user. These are the
          # capabilities upstream's own compose file grants; nothing else.
          NET_RAW = true;
          NET_BIND_SERVICE = true;
          CHOWN = true;
          FOWNER = true;
          SETUID = true;
          SETGID = true;
          DAC_OVERRIDE = true;
          KILL = true;
        };
        extraOptions =
          [
            "--cap-drop=ALL"
            "--read-only"
            "--security-opt=no-new-privileges:true"
          ]
          ++ tmpfsOptions
          ++ [
            "--memory=${srv.resources.memory}"
            "--cpus=${srv.resources.cpus}"
            "--ulimit=nofile=65536:65536"
            # Postgres needs time to checkpoint on stop (upstream: 60s grace).
            "--stop-timeout=60"
            "--health-cmd=curl -fsS --max-time 4 http://127.0.0.1:8080/api/v1/livez | grep -q '\"alive\"'"
            "--health-interval=30s"
            "--health-timeout=5s"
            "--health-retries=3"
            "--health-start-period=60s"
          ];
      };

      # The parent is root-only so no host user can reach the data. The data directory
      # itself is created once and then left alone ("-" = never adjust): the container
      # chowns it to its own uid, and re-owning it on every activation would lock the
      # application out of its database on each rebuild.
      systemd.tmpfiles.rules = [
        "d ${srv.dataDir} 0700 root root -"
        "d ${srv.dataDir}/data - - - -"
      ];

      systemd.services.${unit} = {
        after = ["circuit-breaker-env.service"];
        requires = ["circuit-breaker-env.service"];
        unitConfig.RequiresMountsFor = [srv.dataDir];
        # (oci-containers already allows 120s to stop; the container gets 60s of that.)
        serviceConfig.ExecStartPre = mkIf (srv.tls.certFile != null) ["+${tlsInstall}"];
      };

      # Stages the container's secret env file (generate / external file / Vault).
      systemd.services.circuit-breaker-env = {
        description = "Prepare Circuit Breaker secrets";
        wantedBy = ["multi-user.target"];
        before = ["${unit}.service"];
        unitConfig.RequiresMountsFor = [srv.dataDir];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = secretsRunDir;
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = true;
          UMask = "0077";
          ExecStart = "${stageEnv}";
        };
      };

      # Becomes active only when the application reports ready; everything that
      # talks to the API orders itself after it.
      systemd.services.circuit-breaker-ready = {
        description = "Wait for Circuit Breaker readiness";
        after = ["${unit}.service"];
        requires = ["${unit}.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = readyScript;
          TimeoutStartSec = "12min";
        };
      };

      networking.firewall.allowedTCPPorts = mkIf srv.openFirewall [srv.port];

      environment.systemPackages = [admin];
    }

    (mkIf srv.secrets.vault.enable {
      # The vault-agent integration renders the env file just before the staging unit runs.
      fmf.services.vault-agent.services.circuit-breaker-env = {
        settings = {
          vault.address = srv.secrets.vault.address;
          auto_auth.method = [
            {
              type = "approle";
              config = {
                role_id_file_path = srv.secrets.vault.roleId;
                secret_id_file_path = srv.secrets.vault.secretId;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
        secrets.file.files."circuit-breaker.env" = {
          # Never bounce the database container because a secret was re-read.
          change-action = "none";
          permissions = "0400";
          text = let
            kv = k: ''{{ with secret "${srv.secrets.vault.path}" }}{{ if eq "${srv.secrets.vault.kvVersion}" "v1" }}{{ .Data.${k} }}{{ else }}{{ .Data.data.${k} }}{{ end }}{{ end }}'';
          in
            concatMapStringsSep "\n" (k: "${k}=${kv k}") secretVars + "\n";
        };
      };
    })

    (mkIf srv.backup.enable {
      systemd.services.circuit-breaker-snapshot = {
        description = "Circuit Breaker full-state snapshot";
        after = ["circuit-breaker-ready.service"];
        requires = ["circuit-breaker-ready.service"];
        serviceConfig.Type = "oneshot";
        script = ''
          ${admin}/bin/circuit-breaker-admin snapshot
          # keep the newest N snapshots
          ls -1t ${srv.dataDir}/data/backups/*.tar.gz 2>/dev/null | tail -n +${toString (srv.backup.keep + 1)} | xargs -r rm -f --
        '';
        path = [pkgs.coreutils pkgs.findutils];
      };
      systemd.timers.circuit-breaker-snapshot = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* 03:30:00";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
    })
  ]);
}
