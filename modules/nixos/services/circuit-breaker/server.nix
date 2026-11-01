# Circuit Breaker server, run natively under systemd (no container).
#
# The upstream "mono" image is just these processes under supervisord; here each is a
# hardened systemd unit from nixpkgs or from packages/circuit-breaker-server:
#
#   circuit-breaker-env         stages secrets (generate / external file / Vault)
#   circuit-breaker-postgres    PostgreSQL 15 + TimescaleDB, loopback, own port
#   circuit-breaker-redis       Redis (cache, pub/sub, rate limits), loopback, password
#   circuit-breaker-nats        NATS + JetStream (internal bus), loopback, token
#   circuit-breaker-migrate     database + alembic migrations (oneshot)
#   circuit-breaker-api         uvicorn: API, WebSockets and the web UI
#   circuit-breaker-worker-*    discovery, notification, telemetry, integration, monitor*
#   circuit-breaker-ready       succeeds once /readyz reports ready
#
# All of them run as one unprivileged account inside circuit-breaker.slice, which caps
# their combined memory and CPU. Only the API listens beyond loopback, and only where
# `listenAddress` says.
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
  pkg = srv.package;
  user = srv.user;

  data = "${srv.dataDir}/data";
  secretsDir = "${srv.dataDir}/secrets";
  generatedEnv = "${secretsDir}/server.env";
  vaultFile = "/tmp/detsys-vault/circuit-breaker.env";
  # A runtime directory of its own: never shared with another unit that systemd may clean up.
  secretsRunDir = "circuit-breaker-secrets";
  runtimeEnv = "/run/${secretsRunDir}/server.env";

  # Names the application needs; they are provided only through the env file.
  secretVars = ["CB_DB_PASSWORD" "CB_VAULT_KEY" "CB_JWT_SECRET" "NATS_AUTH_TOKEN"];

  tlsOn = srv.tls.certFile != null;
  scheme =
    if tlsOn
    then "https"
    else "http";
  apiHost =
    if srv.listenAddress == "0.0.0.0" || srv.listenAddress == "::"
    then "127.0.0.1"
    else srv.listenAddress;

  # Private ports for the bundled services: they must not collide with a PostgreSQL,
  # Redis or NATS the host may run for something else.
  pgPort = srv.internalPorts.postgres;
  redisPort = srv.internalPorts.redis;
  natsPort = srv.internalPorts.nats;

  postgres = pkgs.postgresql_15.withPackages (ps: [ps.timescaledb]);
  pgData = "${data}/pgdata";

  # Programs the application shells out to.
  toolPath = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnutar
    pkgs.gzip
    pkgs.curl
    pkgs.openssl
    pkgs.age
    pkgs.nmap
    pkgs.iputils
    pkgs.libcap
    postgres
  ];

  commonEnv =
    {
      CB_DATA_DIR = data;
      UPLOADS_DIR = "${data}/uploads";
      CB_AGENT_BINARIES_DIR = "${data}/agent-binaries";
      NATS_URL = "nats://127.0.0.1:${toString natsPort}";
      CB_AUTO_MIGRATE = "false";
      CB_ALLOW_DIRECT_EGRESS = boolToString srv.egress.allowDirect;
      CB_AIRGAP = boolToString srv.egress.airgap;
      CB_UPDATE_CHECK = boolToString srv.updateCheck;
      CB_TRUSTED_PROXY_CIDRS = concatStringsSep "," srv.trustedProxyCidrs;
      CB_ALLOW_DEGRADED_DEPENDENCIES = "false";
      HOME = data;
    }
    // optionalAttrs (srv.egress.proxyUrl != null) {CB_EGRESS_PROXY_URL = srv.egress.proxyUrl;}
    // srv.extraEnvironment;

  hardening = {
    User = user;
    Group = user;
    Slice = "circuit-breaker.slice";
    EnvironmentFile = runtimeEnv;
    UMask = "0077";
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [srv.dataDir];
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    LockPersonality = true;
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    SystemCallFilter = ["@system-service" "~@privileged"];
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    Restart = "on-failure";
    RestartSec = 5;
  };

  # Every service waits for the staged secrets and restarts with them.
  common = {
    after = ["circuit-breaker-env.service"];
    requires = ["circuit-breaker-env.service"];
    unitConfig.RequiresMountsFor = [srv.dataDir];
  };

  # ---------------------------------------------------------------- secrets

  generateSecrets = pkgs.writeShellScript "circuit-breaker-generate-secrets" ''
    set -euo pipefail
    umask 077
    install -d -m 0700 ${secretsDir}
    if [ -s ${generatedEnv} ]; then
      exit 0   # never regenerate: the database and the vault are keyed to these values
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

  # Validates the chosen secret source and writes the environment the services read.
  # The Redis password is new on every start (Redis only caches); everything derived from a
  # secret (database URL, Redis URL) is computed here so no unit ever builds one.
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
    get() { ${pkgs.gnused}/bin/sed -n "s/^$1=//p" "$src" | head -n1; }
    for v in ${concatStringsSep " " secretVars}; do
      if [ -z "$(get "$v")" ]; then
        echo "circuit-breaker: $src does not define $v" >&2
        exit 1
      fi
    done
    jwt="$(get CB_JWT_SECRET)"; nats="$(get NATS_AUTH_TOKEN)"; vk="$(get CB_VAULT_KEY)"
    if [ "''${#jwt}" -lt 32 ] || [ "''${#nats}" -lt 32 ]; then
      echo "circuit-breaker: CB_JWT_SECRET and NATS_AUTH_TOKEN must be at least 32 characters" >&2
      exit 1
    fi
    if ! printf '%s' "$nats" | grep -qE '^[A-Za-z0-9._~+/=-]+$'; then
      echo "circuit-breaker: NATS_AUTH_TOKEN may only contain letters, digits and . _ ~ + / = -" >&2
      exit 1
    fi
    if [ "$vk" = "$jwt" ]; then
      echo "circuit-breaker: CB_VAULT_KEY and CB_JWT_SECRET must differ" >&2
      exit 1
    fi
    enc() { ${pkgs.jq}/bin/jq -rn --arg v "$1" '$v|@uri'; }
    redis_pw="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
    tmp="$(mktemp /run/${secretsRunDir}/.server.env.XXXXXX)"
    {
      for v in ${concatStringsSep " " secretVars}; do echo "$v=$(get "$v")"; done
      echo "CB_DB_URL=postgresql://breaker:$(enc "$(get CB_DB_PASSWORD)")@127.0.0.1:${toString pgPort}/circuitbreaker"
      echo "CB_REDIS_PASSWORD=$redis_pw"
      echo "CB_REDIS_URL=redis://:$redis_pw@127.0.0.1:${toString redisPort}/0"
    } > "$tmp"
    chmod 0400 "$tmp"
    mv -f "$tmp" ${runtimeEnv}
  '';

  # ---------------------------------------------------------------- postgres

  pgConf = pkgs.writeText "circuit-breaker-postgresql.conf" ''
    listen_addresses = '127.0.0.1'
    port = ${toString pgPort}
    unix_socket_directories = '/run/circuit-breaker-postgres'
    hba_file = '${pgHba}'
    password_encryption = scram-sha-256
    shared_preload_libraries = 'timescaledb'
    timescaledb.telemetry_level = off
    max_connections = 100
    shared_buffers = ${srv.postgres.sharedBuffers}
    wal_level = replica
    fsync = on
    synchronous_commit = on
    full_page_writes = on
    log_destination = 'stderr'
    logging_collector = off
    jit = off
    ${srv.postgres.extraConfig}
  '';
  pgHba = pkgs.writeText "circuit-breaker-pg_hba.conf" ''
    # TCP on loopback with SCRAM only; there is no local-socket access.
    host all all 127.0.0.1/32 scram-sha-256
  '';

  pgPrepare = pkgs.writeShellScript "circuit-breaker-postgres-prepare" ''
    set -euo pipefail
    umask 077
    if [ -f ${pgData}/PG_VERSION ]; then
      exit 0
    fi
    install -d -m 0700 ${pgData}
    pw="$(mktemp)"
    trap 'rm -f "$pw"' EXIT
    printf '%s' "$CB_DB_PASSWORD" > "$pw"
    ${postgres}/bin/initdb -D ${pgData} --username=breaker --pwfile="$pw" \
      --auth-host=scram-sha-256 --auth-local=reject --encoding=UTF8 --locale=C
  '';

  migrate = pkgs.writeShellScript "circuit-breaker-migrate" ''
    set -euo pipefail
    export PGPASSWORD="$CB_DB_PASSWORD" PGHOST=127.0.0.1 PGPORT=${toString pgPort} PGUSER=breaker
    for i in $(seq 1 60); do
      ${postgres}/bin/pg_isready -d postgres >/dev/null 2>&1 && break
      sleep 1
    done
    ${postgres}/bin/pg_isready -d postgres >/dev/null
    exists="$(${postgres}/bin/psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'circuitbreaker'")"
    if [ "$exists" != "1" ]; then
      ${postgres}/bin/psql -d postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE "circuitbreaker" OWNER breaker'
    fi
    cd ${data}
    exec ${pkg}/bin/cb-python -m alembic -c ${pkg}/share/backend/alembic.ini upgrade head
  '';

  # ---------------------------------------------------------------- redis / nats

  # nats-server parses environment variables as config syntax (a token starting with a digit
  # is read as a number), so the whole configuration is written, with the token quoted, into a
  # private runtime file. staging guarantees the token needs no escaping.
  natsPrepare = pkgs.writeShellScript "circuit-breaker-nats-prepare" ''
    set -euo pipefail
    umask 077
    {
      echo 'listen: 127.0.0.1:${toString natsPort}'
      echo 'jetstream { store_dir: "${data}/nats" }'
      printf 'authorization { token: "%s" }\n' "$NATS_AUTH_TOKEN"
    } > "$RUNTIME_DIRECTORY/nats.conf"
  '';

  redisStart = pkgs.writeShellScript "circuit-breaker-redis" ''
    # The password goes in over stdin: it must not appear in the process list.
    printf 'requirepass %s\n' "$CB_REDIS_PASSWORD" | exec ${pkgs.redis}/bin/redis-server - \
      --bind 127.0.0.1 --port ${toString redisPort} --protected-mode yes \
      --dir ${data}/redis --save "" --appendonly no \
      --maxmemory 128mb --maxmemory-policy allkeys-lru
  '';

  # Upstream computes agent TLS pins from <data>/tls/fullchain.pem (the certificate its bundled
  # nginx serves). The API serves its own certificate here, so publish the public half there.
  tlsPublish = pkgs.writeShellScript "circuit-breaker-publish-cert" ''
    set -euo pipefail
    install -d -m 0755 -o ${user} -g ${user} ${data}/tls
    install -m 0644 -o ${user} -g ${user} ${srv.tls.certFile} ${data}/tls/fullchain.pem
  '';

  # ---------------------------------------------------------------- app units

  apiArgs =
    "-m uvicorn app.main:app --host ${srv.listenAddress} --port ${toString srv.port} --workers ${toString srv.apiWorkers} --no-access-log --no-proxy-headers"
    + optionalString tlsOn " --ssl-certfile %d/tls-cert --ssl-keyfile %d/tls-key";

  workerTypes = {
    discovery = {
      type = "discovery";
      raw = true;
    };
    notification.type = "notification";
    telemetry.type = "telemetry";
    integration.type = "integration";
    monitor-scheduler.type = "monitor_scheduler";
    monitor-poll-0.type = "monitor_poll";
    monitor-poll-1.type = "monitor_poll";
    monitor-probe-dispatch.type = "monitor_probe_dispatch";
  };

  mkWorker = name: w:
    nameValuePair "circuit-breaker-worker-${name}" (common
      // {
        description = "Circuit Breaker worker: ${w.type}";
        wantedBy = ["circuit-breaker.target"];
        partOf = ["circuit-breaker.target"];
        after = common.after ++ ["circuit-breaker-migrate.service" "circuit-breaker-redis.service" "circuit-breaker-nats.service" "circuit-breaker-postgres.service"];
        requires = common.requires ++ ["circuit-breaker-migrate.service"];
        path = toolPath;
        environment = commonEnv // {CB_TOPOLOGY_MODE = "worker";};
        serviceConfig =
          hardening
          // {
            WorkingDirectory = data;
            ExecStart = "${pkg}/bin/cb-python -m app.workers.main --type=${w.type}";
            TimeoutStopSec = 30;
          }
          // optionalAttrs (w.raw or false) {
            # ICMP/ARP discovery needs raw sockets - the only capability anywhere in this stack
            CapabilityBoundingSet = "CAP_NET_RAW";
            AmbientCapabilities = "CAP_NET_RAW";
            RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" "AF_PACKET"];
          };
      });

  # ---------------------------------------------------------------- operator helper

  admin = pkgs.writeShellApplication {
    name = "circuit-breaker-admin";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.gnugrep pkgs.curl pkgs.util-linux pkgs.systemd];
    text = ''
      usage() {
        cat <<'EOF'
      circuit-breaker-admin <command>

        status                 service state + readiness
        setup-token            print the one-time first-run setup token
        mint-sync-token        create (or rotate) the flake-sync API token and store it
        agent-key              print the server's public agent identity key (for agent.serverStaticPk)
        snapshot               create a full-state snapshot (contains the vault key!)
        psql [args...]         psql as the application's database role
        cli <args...>          run the upstream admin CLI (python -m app.cli ...)
      EOF
      }
      if [ "$(id -u)" -ne 0 ]; then
        echo "circuit-breaker-admin must run as root (it reads the staged secrets)" >&2
        exit 1
      fi
      load_env() {
        [ -r ${runtimeEnv} ] || { echo "secrets are not staged: is circuit-breaker-env.service running?" >&2; exit 1; }
        while IFS= read -r line; do export "''${line?}"; done < ${runtimeEnv}
        ${concatStringsSep "\n" (mapAttrsToList (k: v: "export ${k}=${escapeShellArg v}") commonEnv)}
        export PATH=${makeBinPath toolPath}:"$PATH"
      }
      # run the app's CLI as the service account, with the service environment
      cb_exec() {
        load_env
        cd ${data}
        setpriv --reuid=${user} --regid=${user} --init-groups ${pkg}/bin/cb-python -m app.cli "$@"
      }
      cmd="''${1:-}"; shift || true
      case "$cmd" in
        status)
          systemctl --no-pager --plain list-units 'circuit-breaker-*.service' --all || true
          curl -ksS --max-time 5 ${scheme}://${apiHost}:${toString srv.port}/api/v1/readyz && echo
          ;;
        setup-token)
          # The token is issued lazily on the first bootstrap-status request.
          status="$(curl -ksS --max-time 10 "${scheme}://${apiHost}:${toString srv.port}/api/v1/bootstrap/status" || true)"
          if [ "$(printf '%s' "$status" | jq -r '.needs_bootstrap // empty')" != "true" ]; then
            echo "first-run setup is already complete (or the server is not answering); no setup token to print." >&2
            exit 1
          fi
          echo "Printing the one-time setup token; do not paste it into logs." >&2
          cat ${data}/bootstrap-setup-token
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
        agent-key)
          load_env
          cd ${data}
          setpriv --reuid=${user} --regid=${user} --init-groups ${pkg}/bin/cb-python - <<'PY'
      from app.core import agent_crypto
      from app.db.session import SessionLocal
      from app.services import vault_service
      from app.services.credential_vault import get_vault

      with SessionLocal() as db:
          # the server key is stored encrypted: unlock the vault the way the API does at startup
          get_vault().reinitialize(vault_service.load_vault_key(db))
          state = agent_crypto.load_server_key_rotation_state(db)
          print((state.successor_pub if state.successor_pub is not None else state.current_pub).hex())
      PY
          ;;
        psql)
          load_env
          PGPASSWORD="$CB_DB_PASSWORD" exec ${postgres}/bin/psql -h 127.0.0.1 -p ${toString pgPort} -U breaker -d circuitbreaker "$@"
          ;;
        cli)
          cb_exec "$@"
          ;;
        *) usage; exit 2 ;;
      esac
    '';
  };
in {
  options.fmf.services.circuit-breaker.server = {
    enable = mkBoolOpt false "Run the Circuit Breaker server on this host.";

    package = mkOpt types.package pkgs.fmf.circuit-breaker-server ''
      The natively built server (packages/circuit-breaker-server): upstream's release, its
      Python dependencies pinned by hash from upstream's poetry.lock, and the web UI built
      from its package-lock.json.
    '';
    dataDir = mkOpt types.str "/var/lib/circuit-breaker" ''
      Persistent state root. `<dataDir>/data` holds the database, bus and uploads;
      `<dataDir>/secrets` holds generated secrets (root only).
    '';
    user = mkOpt types.str "circuit-breaker" "Account every service runs as.";
    uid = mkOpt types.int 1500 ''
      Fixed numeric id of that account (and its group). Pinned on purpose: the data directory
      is usually a shared or persistent volume, and a drifting id would lock the database out.
    '';
    listenAddress = mkOpt types.str "127.0.0.1" ''
      Address the API/UI listens on. Keep it on loopback when a reverse proxy on this host
      publishes it; otherwise use this host's LAN address and set tls.* (never 0.0.0.0).
    '';
    port = mkOpt types.port 8000 "Port the API/UI listens on.";
    apiWorkers = mkOpt types.ints.positive 2 "uvicorn worker processes of the API (each holds a copy of the application in memory).";
    domain = mkOpt (types.nullOr types.str) null ''
      Public host name (e.g. topology.lan.example.com). Used for reverse-proxy integration and docs;
      set the same value as "App URL" in Settings -> Connectivity.
    '';
    openFirewall = mkBoolOpt false "Open the API port in the host firewall.";
    allowPlainHttp = mkBoolOpt false ''
      Permit serving plain HTTP on a non-loopback address (tls.* unset). Off by default: plain
      HTTP is only acceptable on loopback behind a reverse proxy that terminates TLS.
    '';
    trustedProxyCidrs = mkOpt (types.listOf types.str) ["127.0.0.1/32" "::1/128"] ''
      Source ranges whose X-Forwarded-* headers are trusted (CB_TRUSTED_PROXY_CIDRS).
      Add a reverse proxy that is not on this host, otherwise every client shares one rate-limit bucket.
    '';
    updateCheck = mkBoolOpt false "Allow the daily GitHub release check (CB_UPDATE_CHECK). Off: versions are managed by Nix.";
    extraEnvironment = mkOpt (types.attrsOf types.str) {} "Additional non-secret environment variables.";

    tls = {
      certFile = mkOpt (types.nullOr types.str) null "PEM certificate chain served by the API itself (runtime path). null = plain HTTP (loopback behind a TLS-terminating proxy).";
      keyFile = mkOpt (types.nullOr types.str) null "PEM private key matching certFile (runtime path; never a store path). Delivered as a systemd credential.";
    };

    egress = {
      allowDirect = mkBoolOpt true "Allow outbound HTTP without a forward proxy (CB_ALLOW_DIRECT_EGRESS). The app refuses to start unless this or proxyUrl is set.";
      proxyUrl = mkOpt (types.nullOr types.str) null "Forward proxy for outbound HTTP (CB_EGRESS_PROXY_URL).";
      airgap = mkBoolOpt false "Block all outbound calls from the application (CB_AIRGAP).";
    };

    resources = {
      memoryMax = mkOpt types.str "2G" "Hard memory limit of the whole stack (circuit-breaker.slice MemoryMax; systemd syntax, e.g. 2G).";
      cpuQuota = mkOpt types.str "150%" "CPU limit of the whole stack (CPUQuota; 100% = one core).";
    };

    postgres = {
      sharedBuffers = mkOpt types.str "128MB" "shared_buffers of the bundled PostgreSQL.";
      extraConfig = mkOpt types.lines "" "Extra postgresql.conf lines.";
    };

    internalPorts = {
      postgres = mkOpt types.port 15432 "Loopback port of the bundled PostgreSQL.";
      redis = mkOpt types.port 16379 "Loopback port of the bundled Redis.";
      nats = mkOpt types.port 14222 "Loopback port of the bundled NATS.";
    };

    secrets = {
      environmentFile = mkOpt (types.nullOr types.str) null ''
        Runtime path of an env file defining CB_DB_PASSWORD, CB_VAULT_KEY (a Fernet key),
        CB_JWT_SECRET and NATS_AUTH_TOKEN. Must not be in the Nix store.
      '';
      generate = mkBoolOpt false ''
        Create the env file once, at first start, under <dataDir>/secrets (0400, root). Existing
        files are never overwritten: the database and the vault are keyed to these values.
        Back this file up together with <dataDir>/data.
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
          assertion = all (n: !(elem n (secretVars ++ ["CB_DB_URL" "CB_REDIS_URL" "CB_REDIS_PASSWORD"]))) (attrNames srv.extraEnvironment);
          message = "fmf.services.circuit-breaker.server.extraEnvironment must not set ${concatStringsSep "/" secretVars} or the derived database/Redis settings; use server.secrets.";
        }
        {
          assertion = srv.egress.allowDirect || srv.egress.proxyUrl != null || srv.egress.airgap;
          message = "fmf.services.circuit-breaker.server.egress: the app refuses to start with neither allowDirect nor proxyUrl (airgap also satisfies it).";
        }
        {
          assertion = !srv.secrets.vault.enable || config.fmf.services.vault-agent.enable;
          message = "fmf.services.circuit-breaker.server.secrets.vault.enable requires fmf.services.vault-agent.enable.";
        }
        {
          assertion = !(cfg.flakeSync.enable && cfg.flakeSync.tokenFile == null);
          message = "fmf.services.circuit-breaker.flakeSync.tokenFile must be set.";
        }
        {
          assertion = elem srv.listenAddress ["127.0.0.1" "::1"] || tlsOn || srv.allowPlainHttp;
          message = "fmf.services.circuit-breaker.server serves plain HTTP: bind loopback behind a TLS-terminating proxy, set tls.certFile/keyFile, or set allowPlainHttp = true.";
        }
        {
          assertion = length (unique [srv.port pgPort redisPort natsPort]) == 4;
          message = "fmf.services.circuit-breaker.server: port and internalPorts.* must all differ.";
        }
        {
          assertion = srv.uid >= 100 && srv.uid < 65000;
          message = "fmf.services.circuit-breaker.server.uid must be a normal service id.";
        }
        {
          assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
          message = "fmf.services.circuit-breaker.server: the packaged server is locked for x86_64-linux.";
        }
      ];

      warnings =
        optional (srv.listenAddress == "0.0.0.0")
        "fmf.services.circuit-breaker.server.listenAddress is 0.0.0.0: the management UI/API is exposed on every interface. Prefer a specific LAN address."
        ++ optional (srv.openFirewall && elem srv.listenAddress ["127.0.0.1" "::1"])
        "fmf.services.circuit-breaker.server.openFirewall has no effect while listenAddress is loopback.";

      users.users.${user} = {
        isSystemUser = true;
        uid = srv.uid;
        group = user;
        home = data;
        description = "Circuit Breaker";
      };
      users.groups.${user}.gid = srv.uid;

      # The state tree is owned by the service account; the secrets directory is not.
      systemd.tmpfiles.rules = [
        "d ${srv.dataDir} 0755 root root -"
        "d ${data} 0700 ${user} ${user} -"
        "d ${data}/uploads 0700 ${user} ${user} -"
        "d ${data}/agent-binaries 0700 ${user} ${user} -"
        "d ${data}/redis 0700 ${user} ${user} -"
        "d ${data}/nats 0700 ${user} ${user} -"
      ];

      systemd.slices.circuit-breaker = {
        description = "Circuit Breaker";
        sliceConfig = {
          MemoryMax = srv.resources.memoryMax;
          CPUQuota = srv.resources.cpuQuota;
        };
      };
      systemd.targets.circuit-breaker = {
        description = "Circuit Breaker";
        wantedBy = ["multi-user.target"];
        wants = ["circuit-breaker-api.service"];
      };

      systemd.services =
        listToAttrs (mapAttrsToList mkWorker workerTypes)
        // {
          circuit-breaker-env = {
            description = "Prepare Circuit Breaker secrets";
            wantedBy = ["multi-user.target"];
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

          circuit-breaker-postgres =
            common
            // {
              description = "Circuit Breaker PostgreSQL (TimescaleDB)";
              wantedBy = ["circuit-breaker.target"];
              partOf = ["circuit-breaker.target"];
              serviceConfig =
                hardening
                // {
                  Type = "notify";
                  RuntimeDirectory = "circuit-breaker-postgres";
                  RuntimeDirectoryMode = "0700";
                  ExecStartPre = "${pgPrepare}";
                  ExecStart = "${postgres}/bin/postgres -D ${pgData} -c config_file=${pgConf}";
                  KillSignal = "SIGINT";
                  TimeoutStartSec = 300;
                  TimeoutStopSec = 120;
                };
            };

          circuit-breaker-redis =
            common
            // {
              description = "Circuit Breaker Redis";
              wantedBy = ["circuit-breaker.target"];
              partOf = ["circuit-breaker.target"];
              serviceConfig =
                hardening
                // {
                  ExecStart = "${redisStart}";
                  WorkingDirectory = "${data}/redis";
                };
            };

          circuit-breaker-nats =
            common
            // {
              description = "Circuit Breaker NATS";
              wantedBy = ["circuit-breaker.target"];
              partOf = ["circuit-breaker.target"];
              serviceConfig =
                hardening
                // {
                  RuntimeDirectory = "circuit-breaker-nats";
                  RuntimeDirectoryMode = "0700";
                  ExecStartPre = "${natsPrepare}";
                  ExecStart = "${pkgs.nats-server}/bin/nats-server -c %t/circuit-breaker-nats/nats.conf";
                  WorkingDirectory = "${data}/nats";
                };
            };

          circuit-breaker-migrate =
            common
            // {
              description = "Circuit Breaker database migrations";
              after = common.after ++ ["circuit-breaker-postgres.service"];
              requires = common.requires ++ ["circuit-breaker-postgres.service"];
              wantedBy = ["circuit-breaker.target"];
              partOf = ["circuit-breaker.target"];
              path = toolPath;
              environment = commonEnv;
              serviceConfig =
                hardening
                // {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${migrate}";
                  Restart = "no";
                  TimeoutStartSec = 900;
                };
            };

          circuit-breaker-api =
            common
            // {
              description = "Circuit Breaker API and web UI";
              wantedBy = ["circuit-breaker.target"];
              partOf = ["circuit-breaker.target"];
              after = common.after ++ ["circuit-breaker-migrate.service" "circuit-breaker-redis.service" "circuit-breaker-nats.service" "circuit-breaker-postgres.service"];
              requires = common.requires ++ ["circuit-breaker-migrate.service"];
              path = toolPath;
              environment = commonEnv // {CB_TOPOLOGY_MODE = "api";};
              serviceConfig =
                hardening
                // {
                  WorkingDirectory = data;
                  ExecStart = "${pkg}/bin/cb-python ${apiArgs}";
                  TimeoutStopSec = 30;
                }
                // optionalAttrs tlsOn {
                  LoadCredential = ["tls-cert:${srv.tls.certFile}" "tls-key:${srv.tls.keyFile}"];
                  ExecStartPre = "+${tlsPublish}";
                };
            };

          # Becomes active only when the application reports ready; everything that talks to
          # the API orders itself after it.
          circuit-breaker-ready = {
            description = "Wait for Circuit Breaker readiness";
            after = ["circuit-breaker-api.service"];
            requires = ["circuit-breaker-api.service"];
            wantedBy = ["multi-user.target"];
            path = [pkgs.curl];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "12min";
            };
            script = ''
              for i in $(seq 1 240); do
                if curl -ksfS --max-time 4 ${scheme}://${apiHost}:${toString srv.port}/api/v1/readyz >/dev/null 2>&1; then
                  exit 0
                fi
                sleep 3
              done
              echo "circuit-breaker did not become ready within 12 minutes" >&2
              exit 1
            '';
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
          # Never bounce the database because a secret was re-read.
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
          ls -1t ${data}/backups/*.tar.gz 2>/dev/null | tail -n +${toString (srv.backup.keep + 1)} | xargs -r rm -f --
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
