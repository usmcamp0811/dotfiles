# Evaluation-level tests for fmf.services.circuit-breaker: generated systemd
# configuration, secret handling, unit ordering and every invalid option
# combination. Failing any expectation fails the build with the test name.
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  evalWith = extra:
    lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = {inherit lib inputs;};
      modules = [
        ../../modules/nixos/services/vault-agent
        ../../modules/nixos/services/circuit-breaker
        {
          nixpkgs.pkgs = pkgs;
          system.stateVersion = "26.05";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/null";
            fsType = "ext4";
          };
          fmf.services.vault-agent.settings.vault = {
            address = "https://vault.example.invalid";
            role-id = "/synthetic/role-id";
            secret-id = "/synthetic/secret-id";
          };
        }
        extra
      ];
    };

  inventorySrc = pkgs.writeText "inv.json" (builtins.toJSON (import ../../lib/circuit-breaker/tests.nix {inherit lib;}).inv);
  goodAgent = {
    enable = true;
    serverUrl = "https://topology.example.invalid";
    serverStaticPk = lib.concatStrings (lib.replicate 64 "a");
  };
  good = {
    enable = true;
    server = {
      enable = true;
      domain = "topology.example.invalid";
      secrets.generate = true;
    };
    flakeSync = {
      enable = true;
      inventory.source = inventorySrc;
    };
    agent = goodAgent;
  };
  mk = cb: evalWith {fmf.services.circuit-breaker = lib.recursiveUpdate good cb;};
  failed = s: map (a: a.message) (lib.filter (a: !a.assertion) s.config.assertions);
  # `x` must produce an assertion failure mentioning `needle`
  rejects = needle: s: lib.any (m: lib.hasInfix needle m) (failed s);

  ok = mk {};
  c = ok.config;
  svc = c.systemd.services;
  syncExec = svc.circuit-breaker-sync.serviceConfig.ExecStart;
  disabled = evalWith {};
  appUnits = ["circuit-breaker-env" "circuit-breaker-postgres" "circuit-breaker-redis" "circuit-breaker-nats" "circuit-breaker-migrate" "circuit-breaker-api" "circuit-breaker-ready"] ++ map (w: "circuit-breaker-worker-${w}") ["discovery" "notification" "telemetry" "integration" "monitor-scheduler" "monitor-poll-0" "monitor-poll-1" "monitor-probe-dispatch"];
  natsPrepareText = builtins.readFile svc.circuit-breaker-nats.serviceConfig.ExecStartPre;
  svcUnits = lib.filter (n: n != "circuit-breaker-env" && n != "circuit-breaker-ready") appUnits;
  secretNames = ["CB_DB_PASSWORD" "CB_VAULT_KEY" "CB_JWT_SECRET" "NATS_AUTH_TOKEN"];

  tests = {
    "disabled: no units, no assertions" = !(disabled.config.systemd.services ? circuit-breaker-sync) && !(disabled.config.systemd.services ? circuit-breaker-env) && !(disabled.config.systemd.services ? cb-agent) && !(disabled.config.systemd.services ? circuit-breaker-api) && failed disabled == [];
    "enabled: no failed assertions" = failed ok == [];
    "all services and workers are generated" = lib.all (n: svc ? ${n}) (["circuit-breaker-env" "circuit-breaker-postgres" "circuit-breaker-redis" "circuit-breaker-nats" "circuit-breaker-migrate" "circuit-breaker-api" "circuit-breaker-ready"] ++ map (w: "circuit-breaker-worker-${w}") ["discovery" "notification" "telemetry" "integration" "monitor-scheduler" "monitor-poll-0" "monitor-poll-1" "monitor-probe-dispatch"]);
    "secret variables never in any unit's Nix-declared environment" = lib.all (n: !(lib.any (v: svc.${n}.environment ? ${v}) (secretNames ++ ["CB_DB_URL" "CB_REDIS_URL" "CB_REDIS_PASSWORD"]))) appUnits;
    "services read secrets from the runtime env file, not the store" = lib.all (n: svc.${n}.serviceConfig.EnvironmentFile == "/run/circuit-breaker-secrets/server.env") svcUnits;
    "secrets directory is its own RuntimeDirectory" = svc.circuit-breaker-env.serviceConfig.RuntimeDirectory == "circuit-breaker-secrets" && lib.all (n: (svc.${n}.serviceConfig.RuntimeDirectory or "") != "circuit-breaker-secrets") svcUnits;
    "every service runs as the pinned unprivileged account" = lib.all (n: svc.${n}.serviceConfig.User == "circuit-breaker" && svc.${n}.serviceConfig.Group == "circuit-breaker") svcUnits && c.users.users.circuit-breaker.uid == 1500 && c.users.groups.circuit-breaker.gid == 1500;
    "only the discovery worker holds a capability (CAP_NET_RAW)" = lib.all (n: let
      sc = svc.${n}.serviceConfig;
    in
      if n == "circuit-breaker-worker-discovery"
      then sc.AmbientCapabilities == "CAP_NET_RAW"
      else (sc.AmbientCapabilities or "") == "")
    svcUnits;
    "services are sandboxed and in the resource slice" = lib.all (n: let sc = svc.${n}.serviceConfig; in sc.NoNewPrivileges && sc.ProtectSystem == "strict" && sc.PrivateTmp && sc.Slice == "circuit-breaker.slice" && lib.elem "~@privileged" sc.SystemCallFilter) svcUnits;
    "slice caps memory and cpu" =
      c.systemd.slices.circuit-breaker.sliceConfig
      == {
        MemoryMax = "2G";
        CPUQuota = "150%";
      };
    "API is loopback + plain http by default (a TLS proxy terminates)" = let e = svc.circuit-breaker-api.serviceConfig.ExecStart; in lib.hasInfix "--host 127.0.0.1" e && !(lib.hasInfix "--ssl" e) && c.fmf.services.circuit-breaker.scheme == "http";
    "API terminates TLS from credentials when configured" = let
      t = mk {
        server.tls = {
          certFile = "/run/tls/c.pem";
          keyFile = "/run/tls/k.pem";
        };
      };
      sc = t.config.systemd.services.circuit-breaker-api.serviceConfig;
    in
      lib.hasInfix "--ssl-certfile %d/tls-cert --ssl-keyfile %d/tls-key" sc.ExecStart && sc.LoadCredential == ["tls-cert:/run/tls/c.pem" "tls-key:/run/tls/k.pem"] && t.config.fmf.services.circuit-breaker.scheme == "https";
    "bundled postgres/redis/nats bind loopback on private ports" = let
      pgc = builtins.readFile (lib.last (lib.splitString " " (lib.removePrefix "config_file=" (lib.last (lib.splitString " -c " svc.circuit-breaker-postgres.serviceConfig.ExecStart)))));
      natsc = natsPrepareText;
      redisScript = builtins.readFile (lib.head (lib.splitString " " svc.circuit-breaker-redis.serviceConfig.ExecStart));
    in
      lib.hasInfix "listen_addresses = '127.0.0.1'" pgc && lib.hasInfix "port = 15432" pgc && lib.hasInfix "shared_preload_libraries = 'timescaledb'" pgc && lib.hasInfix "listen: 127.0.0.1:14222" natsc && lib.hasInfix "--bind 127.0.0.1 --port 16379" redisScript;
    "postgres allows loopback SCRAM only" = let
      pgc = builtins.readFile (lib.last (lib.splitString " " (lib.removePrefix "config_file=" (lib.last (lib.splitString " -c " svc.circuit-breaker-postgres.serviceConfig.ExecStart)))));
      hba = builtins.readFile (lib.head (builtins.match ".*hba_file = '([^']*)'.*" pgc));
    in
      lib.hasInfix "host all all 127.0.0.1/32 scram-sha-256" hba && !(lib.hasInfix "trust" hba) && !(lib.hasInfix "local " hba);
    "no secret appears on a command line or in a config file" = let
      prep = natsPrepareText;
      redisScript = builtins.readFile (lib.head (lib.splitString " " svc.circuit-breaker-redis.serviceConfig.ExecStart));
    in
      !(lib.hasInfix "--requirepass" redisScript) && !(lib.hasInfix "--auth" svc.circuit-breaker-nats.serviceConfig.ExecStart) && lib.hasInfix "umask 077" prep && lib.hasInfix "$NATS_AUTH_TOKEN" prep && svc.circuit-breaker-nats.serviceConfig.RuntimeDirectoryMode == "0700" && lib.hasInfix "| exec" redisScript;
    "migrations run before the API and every worker" = lib.elem "circuit-breaker-migrate.service" svc.circuit-breaker-api.requires && lib.all (n: lib.elem "circuit-breaker-migrate.service" svc.${n}.requires) (lib.filter (lib.hasPrefix "circuit-breaker-worker-") appUnits);
    "migrate waits for postgres; services wait for the secrets" = lib.elem "circuit-breaker-postgres.service" svc.circuit-breaker-migrate.requires && lib.all (n: lib.elem "circuit-breaker-env.service" svc.${n}.requires) (lib.filter (n: n != "circuit-breaker-env" && n != "circuit-breaker-ready") appUnits);
    "readiness gate orders after the API" = lib.elem "circuit-breaker-api.service" svc.circuit-breaker-ready.requires;
    "firewall is not opened by default" = !(lib.elem 8000 c.networking.firewall.allowedTCPPorts);
    "state tree is owned by the service account" = lib.elem "d /var/lib/circuit-breaker/data 0700 circuit-breaker circuit-breaker -" c.systemd.tmpfiles.rules;
    "every generated unit file renders (no conflicting definitions)" = let
      full = mk {
        server.backup.enable = true;
        server.tls = {
          certFile = "/run/tls/c.pem";
          keyFile = "/run/tls/k.pem";
        };
        flakeSync.git = {
          enable = true;
          url = "https://git.example.invalid/c.git";
        };
        agent.enrollTokenFile = "/run/secrets/t";
      };
      names = appUnits ++ ["circuit-breaker-provision" "circuit-breaker-snapshot" "circuit-breaker-sync" "circuit-breaker-sync-git" "cb-agent"];
    in
      lib.all (n: builtins.stringLength full.config.systemd.units."${n}.service".text > 0) names && builtins.stringLength full.config.systemd.units."circuit-breaker-snapshot.timer".text > 0 && builtins.stringLength full.config.systemd.units."circuit-breaker.target".text > 0 && builtins.stringLength full.config.systemd.units."circuit-breaker.slice".text > 0 && builtins.stringLength full.config.environment.etc."circuit-breaker/agent.toml".source > 0;
    "sync orders after readiness" = lib.elem "circuit-breaker-ready.service" svc.circuit-breaker-sync.after;
    "sync consumes a build-time inventory store path" = lib.hasInfix "--apply --inventory ${builtins.unsafeDiscardStringContext (toString inventorySrc)}" (builtins.unsafeDiscardStringContext syncExec);
    "sync reads the token as a systemd credential, not an argument" = lib.hasInfix "--token-file %d/token" syncExec && lib.any (lib.hasSuffix "/sync-token") svc.circuit-breaker-sync.serviceConfig.LoadCredential && !(lib.hasInfix "sync-token" syncExec);
    "sync talks plain http to a loopback API (no pin)" = !(lib.hasInfix "--tls-pin-file" syncExec) && lib.hasInfix "--url http://127.0.0.1:8000" syncExec;
    "sync pins the server certificate when the API serves TLS" = let
      t = mk {
        server.tls = {
          certFile = "/run/tls/c.pem";
          keyFile = "/run/tls/k.pem";
        };
      };
      sc = t.config.systemd.services.circuit-breaker-sync.serviceConfig;
    in
      lib.hasInfix "--tls-pin-file %d/server-cert" sc.ExecStart && lib.hasInfix "--url https://" sc.ExecStart && lib.any (lib.hasPrefix "server-cert:/run/tls/c.pem") sc.LoadCredential;
    "sync is sandboxed without capabilities" = svc.circuit-breaker-sync.serviceConfig.CapabilityBoundingSet == "" && svc.circuit-breaker-sync.serviceConfig.NoNewPrivileges && svc.circuit-breaker-sync.serviceConfig.User == "circuit-breaker-sync";
    "sync does not retry unrecoverable exit codes" = svc.circuit-breaker-sync.serviceConfig.RestartPreventExitStatus == "2 3 6 7";
    "no git timer unless enabled" = !(svc ? circuit-breaker-sync-git) && !(c.systemd.timers ? circuit-breaker-sync-git);
    "git sync: timer + unit when enabled" = let
      g = mk {
        flakeSync.git = {
          enable = true;
          url = "https://git.example.invalid/c.git";
          ref = "main";
        };
      };
    in
      g.config.systemd.timers ? circuit-breaker-sync-git && lib.hasInfix "--sync-git" g.config.systemd.services.circuit-breaker-sync-git.serviceConfig.ExecStart && failed g == [];
    "policy defaults are non-destructive" = let
      p = builtins.fromJSON (builtins.readFile (lib.head (lib.filter (lib.hasInfix "policy.json") (lib.splitString " " syncExec))));
    in
      p.retire == "tag" && p.allow_delete == false && p.prune_relationships == false && p.discovery == [];
    "agent: unprivileged, netlink allowed, no capabilities" = let
      a = svc.cb-agent.serviceConfig;
    in
      a.User == "cb-agent" && a.CapabilityBoundingSet == "" && lib.elem "AF_NETLINK" a.RestrictAddressFamilies && !(lib.elem "AF_PACKET" a.RestrictAddressFamilies) && a.NoNewPrivileges;
    "agent: opens no firewall ports" = c.networking.firewall.allowedTCPPorts == (evalWith {}).config.networking.firewall.allowedTCPPorts;
    "agent: config is a symlink to the rendered runtime file" = c.environment.etc."circuit-breaker/agent.toml".source == "/run/cb-agent/agent.toml";
    "agent: enrollment token only through a credential" = let
      a = (mk {agent.enrollTokenFile = "/run/secrets/cb-enroll";}).config.systemd.services.cb-agent.serviceConfig;
    in
      a.LoadCredential == ["enroll-token:/run/secrets/cb-enroll"];
    "agent-only host has no server units" = let
      s = evalWith {
        fmf.services.circuit-breaker = {
          enable = true;
          agent = goodAgent;
        };
      };
    in
      !(s.config.systemd.services ? circuit-breaker-ready) && s.config.systemd.services ? cb-agent && failed s == [];
    "vault secrets: rendered via vault-agent, change-action none" = let
      v = evalWith {
        fmf.services.vault-agent.enable = true;
        fmf.services.circuit-breaker = lib.recursiveUpdate good {
          server.secrets = {
            generate = false;
            vault.enable = true;
          };
        };
      };
      f = v.config.detsys.vaultAgent.systemd.services.circuit-breaker-env;
    in
      failed v == [] && f.secretFiles.files."circuit-breaker.env".changeAction == "none";
    # Regression: <dataDir>/secrets is only created when the module generates the secrets. With
    # Vault nothing creates it, the post-restart `touch` of the marker failed, and the provision
    # unit restarted the whole stack every minute. The directory must exist BEFORE any restart.
    "provision creates the marker directory before it restarts anything (vault secrets)" = let
      v = evalWith {
        fmf.services.vault-agent.enable = true;
        fmf.services.circuit-breaker = lib.recursiveUpdate good {
          server.secrets = {
            generate = false;
            vault.enable = true;
          };
        };
      };
      script = v.config.systemd.services.circuit-breaker-provision.script;
      beforeRestart = builtins.head (lib.splitString "systemctl restart" script);
    in
      lib.hasInfix ''install -d -m 0700 "$(dirname "$marker")"'' beforeRestart;
    "hints option is inert on ordinary hosts" =
      (evalWith {
        fmf.services.circuit-breaker.hints = {
          location = "garage";
          devices.sw = {
            role = "switch";
            address = "10.0.0.2";
          };
        };
      }).config.fmf.services.circuit-breaker.hints.devices.sw.role
      == "switch";

    # ---- invalid combinations must be rejected
    "reject: plain http on a LAN address" = rejects "serves plain HTTP" (mk {server.listenAddress = "10.0.0.5";});
    "accept: plain http on a LAN address when explicitly allowed" =
      failed (mk {
        server.listenAddress = "10.0.0.5";
        server.allowPlainHttp = true;
      })
      == [];
    "reject: colliding ports" = rejects "must all differ" (mk {
      server.internalPorts.redis = 5432;
      server.internalPorts.postgres = 5432;
    });
    "reject: a system uid below 100" = rejects "normal service id" (mk {server.uid = 5;});
    "reject: no secret source" = rejects "choose exactly one" (mk {server.secrets.generate = false;});
    "reject: two secret sources" = rejects "choose exactly one" (mk {server.secrets.environmentFile = "/run/x";});
    "reject: env file in the store" = rejects "must not be in the Nix store" (mk {
      server.secrets = {
        generate = false;
        environmentFile = "${pkgs.writeText "e" "x"}";
      };
    });
    "reject: half a TLS pair" = rejects "set both certFile and keyFile" (mk {server.tls.certFile = "/run/c.pem";});
    "reject: TLS key from the store" = rejects "runtime paths" (mk {
      server.tls = {
        certFile = "/run/c.pem";
        keyFile = "${pkgs.writeText "k" "x"}";
      };
    });
    "reject: secret smuggled through extraEnvironment" = rejects "must not set" (mk {server.extraEnvironment.CB_JWT_SECRET = "x";});
    "reject: no egress mode" = rejects "egress" (mk {server.egress.allowDirect = false;});
    "reject: vault without vault-agent" = rejects "requires fmf.services.vault-agent" (evalWith {
      fmf.services.circuit-breaker = lib.recursiveUpdate good {
        server.secrets = {
          generate = false;
          vault.enable = true;
        };
      };
      fmf.services.vault-agent.enable = lib.mkForce false;
    });
    "reject: neither server nor agent" = rejects "neither server.enable nor agent.enable" (evalWith {fmf.services.circuit-breaker.enable = true;});
    "reject: sync without server" = rejects "requires server.enable" (mk {server.enable = false;});
    "reject: sync without any inventory source" = rejects "needs an inventory source" (mk {flakeSync.inventory.source = null;});
    "reject: git without url" = rejects "git.url must be set" (mk {flakeSync.git.enable = true;});
    "reject: git url with embedded credentials" = rejects "must not embed credentials" (mk {
      flakeSync.git = {
        enable = true;
        url = "https://user:pw@git.example.invalid/c.git";
      };
    });
    "reject: git url with unsupported scheme" = rejects "https:// or ssh://" (mk {
      flakeSync.git = {
        enable = true;
        url = "file:///etc";
      };
    });
    "reject: delete without allowDelete" = rejects "allowDelete" (mk {flakeSync.policy.retire = "delete";});
    "reject: token in the store" = rejects "must not be in the Nix store" (mk {flakeSync.tokenFile = "${pkgs.writeText "t" "x"}";});
    "reject: discovery enabled without profiles" = rejects "requires at least one profile" (mk {monitoring.discovery.enable = true;});
    "reject: discovery wider than /16" = rejects "wider than /16" (mk {
      monitoring.discovery = {
        enable = true;
        profiles.all.cidr = "10.0.0.0/8";
      };
    });
    "reject: discovery of a public range" = rejects "not a private range" (mk {
      monitoring.discovery = {
        enable = true;
        profiles.pub.cidr = "8.8.8.0/24";
      };
    });
    "accept: bounded private discovery" =
      failed (mk {
        monitoring.discovery = {
          enable = true;
          profiles.lan = {
            cidr = "10.8.0.0/24";
            schedule = "0 3 * * *";
          };
        };
      })
      == [];
    "discovery profiles are not emitted unless authorised" = let
      s = mk {
        monitoring.discovery = {
          enable = false;
          profiles.lan.cidr = "10.8.0.0/24";
        };
      };
      p = builtins.fromJSON (builtins.readFile (lib.head (lib.filter (lib.hasInfix "policy.json") (lib.splitString " " s.config.systemd.services.circuit-breaker-sync.serviceConfig.ExecStart))));
    in
      p.discovery == [];
    "reject: agent over plain http" = rejects "https://" (mk {agent.serverUrl = "http://topology.example.invalid";});
    "reject: agent url with a path" = rejects "no path" (mk {agent.serverUrl = "https://topology.example.invalid/cb";});
    "reject: agent without server key" = rejects "exactly one of serverStaticPk" (mk {agent.serverStaticPk = lib.mkForce null;});
    "reject: agent with malformed key" = rejects "64 lowercase hex" (mk {agent.serverStaticPk = lib.mkForce "xyz";});
    "reject: agent token from the store" = rejects "runtime paths" (mk {agent.enrollTokenFile = "${pkgs.writeText "t" "x"}";});
  };

  bad = lib.attrNames (lib.filterAttrs (_: v: v != true) tests);
in
  assert lib.assertMsg (bad == []) "circuit-breaker module tests failed: ${builtins.toJSON bad}; baseline assertion failures: ${builtins.toJSON (failed ok)}";
    pkgs.runCommand "circuit-breaker-module-check" {} ''
      echo "${toString (lib.length (lib.attrNames tests))} module tests passed" | tee $out
    ''
