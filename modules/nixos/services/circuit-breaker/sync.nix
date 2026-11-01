# Inventory synchronisation: flake -> Circuit Breaker.
#
# Two complementary triggers, one reconciler (`circuit-breaker-sync`):
#
#   deployment-driven  the inventory is generated at *build* time from the exact
#                      configurations being deployed and referenced by the unit,
#                      so `nixos-rebuild`/`deploy` restarts the sync with it. No
#                      mutable Git checkout is read at runtime.
#   git-driven         a timer resolves one configured, trusted ref, evaluates
#                      that exact revision and syncs when it moved.
#
# Declared (committed) state, newly evaluated desired state and actually
# deployed state are three different things; see docs/CIRCUIT-BREAKER.md.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.circuit-breaker;
  fs = cfg.flakeSync;
  srv = cfg.server;
  cb = lib.fmf.circuitBreaker;

  stateName = "circuit-breaker-sync";
  stateDir = "/var/lib/${stateName}";
  apiHost =
    if srv.listenAddress == "0.0.0.0" || srv.listenAddress == "::"
    then "127.0.0.1"
    else srv.listenAddress;
  tlsOn = srv.tls.certFile != null;
  apiUrl = "${cfg.scheme}://${apiHost}:${toString srv.port}";
  # With TLS the server's own certificate is pinned (read afresh at every start, so renewals work).
  serverCert = srv.tls.certFile;
  user = "circuit-breaker-sync";

  exporterOptions =
    fs.inventory.exporter
    // {
      monitoring = {
        inherit (cfg.monitoring) enable intervalSecs icmp ssh http httpVerifyTls tcpKinds dnsQueryName exclude;
      };
    };

  generatedInventory =
    if fs.inventory.nixosConfigurations == null
    then null
    else
      cb.mkInventoryFile pkgs (cb.mkInventory {
        nixosConfigurations = fs.inventory.nixosConfigurations;
        flake = fs.inventory.flake;
        options = exporterOptions;
      });

  inventoryFile =
    if fs.inventory.source != null
    then fs.inventory.source
    else generatedInventory;

  discoveryProfiles =
    if cfg.monitoring.discovery.enable
    then
      mapAttrsToList (name: p:
        {
          inherit name;
          cidr = p.cidr;
          scan_types = p.scanTypes;
          enabled = p.enable;
        }
        // optionalAttrs (p.schedule != null) {schedule_cron = p.schedule;}
        // optionalAttrs (p.nmapArguments != null) {nmap_arguments = p.nmapArguments;})
      cfg.monitoring.discovery.profiles
    else [];

  policy = pkgs.writeText "circuit-breaker-sync-policy.json" (builtins.toJSON ({
      adopt = fs.policy.adopt;
      retire = fs.policy.retire;
      retire_grace_days = fs.policy.retireGraceDays;
      allow_delete = fs.policy.allowDelete;
      prune_relationships = fs.policy.pruneRelationships;
      max_shrink_percent = fs.policy.maxShrinkPercent;
      sync_monitors = cfg.monitoring.enable;
      remote_probes = cfg.monitoring.remoteProbes;
      discovery = discoveryProfiles;
      discovery_allow_public = cfg.monitoring.discovery.allowPublicRanges;
    }
    // optionalAttrs fs.git.enable {
      git = {
        url = fs.git.url;
        ref = fs.git.ref;
        attr = fs.git.attr;
        build_timeout = fs.git.buildTimeoutSecs;
      };
    }));

  commonArgs =
    [
      "--url ${apiUrl}"
      "--token-file %d/token"
    ]
    ++ optional tlsOn "--tls-pin-file %d/server-cert"
    ++ [
      "--state-dir ${stateDir}"
      "--policy-file ${policy}"
    ];
  extraFlags = optional fs.allowUntestedVersion "--allow-untested";

  # Operator entry point: the same URL/credentials/policy/state as the services, so
  #   sudo cb-sync --dry-run | --apply | --validate | --status [--live]
  # behaves exactly like the timers do. Reads the root-only token, hence sudo.
  cbSync = pkgs.writeShellApplication {
    name = "cb-sync";
    runtimeInputs = [pkgs.git config.nix.package];
    text = ''
      export CB_SYNC_URL=${escapeShellArg apiUrl}
      export CB_SYNC_TOKEN_FILE=${escapeShellArg fs.tokenFile}
      ${optionalString tlsOn "export CB_SYNC_TLS_PIN_FILE=${escapeShellArg serverCert}"}
      export CB_SYNC_STATE_DIR=${escapeShellArg stateDir}
      export CB_SYNC_POLICY_FILE=${policy}
      ${optionalString (inventoryFile != null) "export CB_SYNC_INVENTORY=${inventoryFile}"}
      if [ "$(id -u)" -ne 0 ]; then
        echo "cb-sync reads the root-only API token; run it with sudo" >&2
        exit 1
      fi
      exec ${fs.package}/bin/circuit-breaker-sync "$@" ${concatStringsSep " " extraFlags}
    '';
  };

  hardening = {
    User = user;
    Group = user;
    StateDirectory = stateName;
    StateDirectoryMode = "0750";
    LoadCredential =
      ["token:${fs.tokenFile}"]
      ++ optional tlsOn "server-cert:${serverCert}";
    WorkingDirectory = stateDir;
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    SystemCallFilter = ["@system-service" "~@privileged"];
    CapabilityBoundingSet = "";
    # exit codes that retrying cannot fix: invalid inventory, auth, incompatible, guard
    RestartPreventExitStatus = "2 3 6 7";
  };

  mkSyncUnit = {
    description,
    mode,
    extraEnv ? {},
    extraPath ? [],
    extraCredentials ? [],
    timeout ? "30min",
    wantedBy ? [],
    remainAfterExit ? false,
  }: {
    inherit description wantedBy;
    after = ["circuit-breaker-ready.service" "network-online.target"];
    wants = ["circuit-breaker-ready.service" "network-online.target"];
    path = extraPath;
    environment = {HOME = stateDir;} // extraEnv;
    unitConfig.ConditionPathExists = fs.tokenFile;
    serviceConfig =
      hardening
      // {
        Type = "oneshot";
        RemainAfterExit = remainAfterExit;
        LoadCredential = hardening.LoadCredential ++ extraCredentials;
        ExecStart = "${fs.package}/bin/circuit-breaker-sync ${mode} ${concatStringsSep " " (commonArgs ++ extraFlags)}";
        TimeoutStartSec = timeout;
        Restart = "on-failure";
        RestartSec = "2min";
      };
  };

  net = cb.net;
  privateRanges = ["10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10"];
  profileProblem = name: p: let
    c = net.parseCidr p.cidr;
  in
    if c == null
    then "profile ${name}: invalid CIDR ${p.cidr}"
    else if c.family == "ipv4" && c.prefixLength < 16
    then "profile ${name}: ${p.cidr} is wider than /16"
    else if c.family == "ipv6" && c.prefixLength < 48
    then "profile ${name}: ${p.cidr} is wider than /48"
    else if !cfg.monitoring.discovery.allowPublicRanges && c.family == "ipv4" && !(any (r: net.inCidr r c.network) privateRanges)
    then "profile ${name}: ${p.cidr} is not a private range (set allowPublicRanges to override)"
    else if !cfg.monitoring.discovery.allowPublicRanges && c.family == "ipv6" && !(hasPrefix "fd" (toLower c.address) || hasPrefix "fc" (toLower c.address))
    then "profile ${name}: ${p.cidr} is not a ULA range"
    else null;
  profileProblems = filter (x: x != null) (mapAttrsToList profileProblem cfg.monitoring.discovery.profiles);
in {
  options.fmf.services.circuit-breaker.flakeSync = {
    enable = mkBoolOpt false "Keep Circuit Breaker's topology in sync with this flake (requires server.enable on this host).";
    package = mkOpt types.package pkgs.fmf.circuit-breaker-sync "The reconciler package.";
    tokenFile = mkOpt types.str "${stateDir}/sync-token" ''
      File holding the API token used by the reconciler (root-owned, 0400; loaded
      into the unprivileged sync units with LoadCredential). Created by the
      provisioning timer once the first administrator exists, or by
      `circuit-breaker-admin mint-sync-token`.
    '';
    token.expiresInDays = mkOpt (types.nullOr types.ints.positive) null "Expire the minted token after N days (null = never; revoke or rotate it instead).";
    allowUntestedVersion = mkBoolOpt false "Proceed against a Circuit Breaker whose minor version differs from the tested one.";

    inventory = {
      nixosConfigurations = mkOpt (types.nullOr (types.attrsOf types.raw)) null ''
        The evaluated systems to export, normally `inputs.self.nixosConfigurations`.
        With this set, the inventory is generated at build time from the exact
        configurations being deployed (deployment-driven sync).
      '';
      source = mkOpt (types.nullOr types.path) null "A pre-built inventory file (overrides nixosConfigurations).";
      flake = mkOpt (types.attrsOf types.anything) {} "Source metadata recorded in the inventory, e.g. `{ name = \"campground\"; rev = inputs.self.rev or null; }`.";
      exporter = mkOpt (types.attrsOf types.anything) {} "Exporter options (excludeSystems, ignoreServices, extraCatalog, includeUnmatchedReservations).";
      file = mkOption {
        type = types.nullOr types.path;
        readOnly = true;
        default = inventoryFile;
        defaultText = literalExpression "<generated inventory>";
        description = "The inventory file the deployment-driven sync uses (read-only; inspect it with `jq`).";
      };
    };

    policyFile = mkOption {
      type = types.path;
      readOnly = true;
      default = policy;
      defaultText = literalExpression "<generated policy>";
      description = "The effective reconciler policy (read-only).";
    };

    git = {
      enable = mkBoolOpt false "Also follow a trusted Git ref and sync when it moves.";
      url = mkOpt types.str "" "Repository URL (https:// without embedded credentials, or ssh://). Fixed in the configuration; never taken from the command line.";
      extraAllowedSchemes = mkOpt (types.listOf (types.enum ["file" "git" "http"])) [] "URL schemes accepted in addition to https/ssh. `file` is for tests and air-gapped mirrors; `http`/`git` are unauthenticated and unencrypted and should not be used across a network.";
      ref = mkOpt types.str "main" "Trusted branch or tag.";
      attr = mkOpt types.str "circuit-breaker-inventory" "Flake package (snowfall: packages.<system>.<attr>) that builds the inventory JSON.";
      credentialFile = mkOpt (types.nullOr types.str) null "git-credential-store file (runtime secret) for private repositories.";
      buildTimeoutSecs = mkOpt types.ints.positive 3600 "Evaluation/build timeout.";
    };

    interval = mkOpt types.str "5m" "How often the Git ref is checked (systemd time span).";
    reconcileInterval = mkOpt (types.nullOr types.str) null ''
      Re-apply the deployment inventory on this interval to repair manual drift of
      flake-owned fields (e.g. "1h"). null = only on deployment.
    '';

    policy = {
      adopt = mkOpt (types.listOf (types.enum ["name" "ip" "mac" "cidr"])) ["name" "ip" "cidr"] "Which attributes may adopt a pre-existing unmanaged entity instead of creating a duplicate.";
      retire = mkOpt (types.enum ["tag" "delete" "ignore"]) "tag" ''
        What happens when a resource disappears from the flake. `tag` (default) only
        marks it `nix:retired` and pauses its monitors. `delete` additionally removes
        it after retireGraceDays and requires allowDelete.
      '';
      retireGraceDays = mkOpt types.ints.unsigned 30 "Days a retired resource is kept before `delete` may remove it.";
      allowDelete = mkBoolOpt false "Permit hard deletes (only with retire = \"delete\").";
      pruneRelationships = mkBoolOpt false "Remove memberships/dependencies between flake-owned entities that are no longer declared.";
      maxShrinkPercent = mkOpt (types.ints.between 0 100) 50 "Abort when the inventory shrinks by more than this percentage versus the last successful sync (0 disables).";
    };
  };

  config = mkIf (cfg.enable && fs.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = srv.enable;
          message = "fmf.services.circuit-breaker.flakeSync requires server.enable on the same host (the reconciler talks to the local API and reads the local certificate).";
        }
        {
          assertion = inventoryFile != null || fs.git.enable;
          message = "fmf.services.circuit-breaker.flakeSync needs an inventory source: set inventory.nixosConfigurations (or inventory.source) and/or git.enable.";
        }
        {
          assertion = !fs.git.enable || fs.git.url != "";
          message = "fmf.services.circuit-breaker.flakeSync.git.url must be set when git.enable is true.";
        }
        {
          assertion = !fs.git.enable || (builtins.match "[a-z+]+://[^/@]*:[^/@]*@.*" fs.git.url == null);
          message = "fmf.services.circuit-breaker.flakeSync.git.url must not embed credentials; use git.credentialFile.";
        }
        {
          assertion = !fs.git.enable || builtins.match "(${concatStringsSep "|" (["https" "ssh" "git\\+https" "git\\+ssh"] ++ fs.git.extraAllowedSchemes)})://.*" fs.git.url != null;
          message = "fmf.services.circuit-breaker.flakeSync.git.url must be an https:// or ssh:// URL (see git.extraAllowedSchemes).";
        }
        {
          assertion = fs.policy.retire != "delete" || fs.policy.allowDelete;
          message = "fmf.services.circuit-breaker.flakeSync.policy.retire = \"delete\" requires policy.allowDelete = true.";
        }
        {
          assertion = !(hasPrefix builtins.storeDir fs.tokenFile);
          message = "fmf.services.circuit-breaker.flakeSync.tokenFile must not be in the Nix store.";
        }
        {
          assertion = profileProblems == [];
          message = "fmf.services.circuit-breaker.monitoring.discovery: ${concatStringsSep "; " profileProblems}";
        }
      ];

      warnings =
        optional (fs.git.enable && inventoryFile != null)
        "fmf.services.circuit-breaker.flakeSync: both deployment-driven and git-driven sync are enabled; the most recent run wins (the git ref describes desired state, the deployment inventory describes what is being deployed).";

      users.users.${user} = {
        isSystemUser = true;
        group = user;
        description = "Circuit Breaker inventory reconciler";
      };
      users.groups.${user} = {};

      environment.systemPackages = [cbSync];

      # Mint the sync token as soon as an administrator exists. The human step
      # (first administrator, via the web UI) cannot be automated safely.
      systemd.services.circuit-breaker-provision = {
        description = "Provision the Circuit Breaker flake-sync API token";
        # Only ordered after (and wanting) the API, never `Requires=`: this unit restarts the API
        # once after first-run setup, which would otherwise stop the unit doing it.
        after = ["circuit-breaker-ready.service"];
        wants = ["circuit-breaker-ready.service"];
        unitConfig.ConditionPathExists = "!${fs.tokenFile}";
        path = [srv.adminPackage pkgs.jq pkgs.curl pkgs.coreutils pkgs.systemd];
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          # Cheap HTTP probe first: this timer runs every minute until a human has
          # finished first-run setup, and the admin CLI (a full Python application
          # start) is far too heavy to run that often.
          setup="$(curl -ksS --max-time 10 ${apiUrl}/api/v1/bootstrap/status 2>/dev/null | jq -r 'if .needs_bootstrap == false then "done" else "pending" end' 2>/dev/null || echo pending)"
          if [ "$setup" != "done" ]; then
            echo "first-run setup is not complete; open the web UI (token: circuit-breaker-admin setup-token)"
            exit 0
          fi
          admins="$(circuit-breaker-admin cli user list --json 2>/dev/null | jq '[.[] | select(.role == "admin" and .is_active == true)] | length' 2>/dev/null || echo 0)"
          if [ "''${admins:-0}" -lt 1 ]; then
            echo "no active administrator; create one with: circuit-breaker-admin cli user create --role admin ..."
            exit 0
          fi
          # The first-run wizard replaces the vault key with a freshly generated one (kept in
          # <data>/.env). Only the process that handled that request switches to it; every other
          # API worker and worker process still holds the old key and would fail to decrypt what
          # the new key encrypted. Restart them once so all of them load the key from disk.
          marker=${srv.dataDir}/secrets/.vault-key-adopted
          if [ ! -e "$marker" ]; then
            echo "first-run setup finished: restarting the application services so every process adopts the new vault key"
            systemctl restart circuit-breaker-api.service 'circuit-breaker-worker-*.service'
            systemctl start circuit-breaker-ready.service
            touch "$marker"
          fi
          circuit-breaker-admin mint-sync-token
          systemctl start --no-block circuit-breaker-sync.service circuit-breaker-sync-git.service 2>/dev/null || true
        '';
      };
      systemd.timers.circuit-breaker-provision = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitInactiveSec = "1min";
        };
      };
    }

    (mkIf (inventoryFile != null) {
      # The inventory store path is part of ExecStart, so a deployment that changes
      # the inventory changes the unit and switch-to-configuration restarts it.
      systemd.services.circuit-breaker-sync = mkSyncUnit {
        description = "Circuit Breaker: sync the deployed flake inventory";
        mode = "--apply --inventory ${inventoryFile}";
        wantedBy = ["multi-user.target"];
        remainAfterExit = true;
      };
      systemd.timers.circuit-breaker-sync = mkIf (fs.reconcileInterval != null) {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "10min";
          OnUnitInactiveSec = fs.reconcileInterval;
        };
      };
    })

    (mkIf fs.git.enable {
      systemd.services.circuit-breaker-sync-git = mkSyncUnit {
        description = "Circuit Breaker: sync the trusted Git ref";
        mode = "--sync-git";
        extraPath = [config.nix.package pkgs.git];
        extraEnv =
          {
            GIT_TERMINAL_PROMPT = "0";
          }
          // optionalAttrs (fs.git.credentialFile != null) {CB_SYNC_GIT_CREDENTIAL_FILE = "%d/git-credentials";};
        extraCredentials = optional (fs.git.credentialFile != null) "git-credentials:${fs.git.credentialFile}";
        timeout = "${toString (fs.git.buildTimeoutSecs + 600)}s";
      };
      systemd.timers.circuit-breaker-sync-git = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "3min";
          OnUnitInactiveSec = fs.interval;
          RandomizedDelaySec = "30s";
        };
      };
    })
  ]);
}
