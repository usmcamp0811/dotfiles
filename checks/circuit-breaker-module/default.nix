# Evaluation-level tests for fmf.services.circuit-breaker: generated systemd/OCI
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
  cont = c.virtualisation.oci-containers.containers.circuit-breaker;
  syncExec = svc.circuit-breaker-sync.serviceConfig.ExecStart;
  disabled = evalWith {};
  noStoreSecret = !(lib.any (lib.hasPrefix builtins.storeDir) cont.environmentFiles);
  secretNames = ["CB_DB_PASSWORD" "CB_VAULT_KEY" "CB_JWT_SECRET" "NATS_AUTH_TOKEN"];

  tests = {
    "disabled: no units, no container, no assertions" = !(disabled.config.systemd.services ? circuit-breaker-sync) && !(disabled.config.systemd.services ? circuit-breaker-env) && !(disabled.config.systemd.services ? cb-agent) && !(disabled.config.virtualisation.oci-containers.containers ? circuit-breaker) && failed disabled == [];
    "enabled: no failed assertions" = failed ok == [];
    "image is pinned by digest" = lib.hasInfix "@sha256:" cont.image;
    "secret variables never in the Nix-declared environment" = lib.all (n: !(cont.environment ? ${n})) secretNames;
    "container env file is a runtime path, not the store" = noStoreSecret && cont.environmentFiles == ["/run/circuit-breaker-secrets/server.env"];
    "container is not privileged" = cont.privileged == false;
    "container drops all capabilities and only re-adds upstream's set" = lib.elem "--cap-drop=ALL" cont.extraOptions && lib.attrNames (lib.filterAttrs (_: v: v) cont.capabilities) == ["CHOWN" "DAC_OVERRIDE" "FOWNER" "KILL" "NET_BIND_SERVICE" "NET_RAW" "SETGID" "SETUID"];
    "container fs is read-only, no-new-privileges" = lib.elem "--read-only" cont.extraOptions && lib.elem "--security-opt=no-new-privileges:true" cont.extraOptions;
    "no container runtime socket is mounted" = !(lib.any (v: lib.hasInfix ".sock" v) cont.volumes);
    "only the data directory is mounted" = cont.volumes == ["/var/lib/circuit-breaker/data:/data"];
    "UI binds loopback by default, probe port is loopback" = lib.all (p: lib.hasPrefix "127.0.0.1:" p) cont.ports;
    "firewall is not opened by default" = !(lib.elem 8443 c.networking.firewall.allowedTCPPorts);
    "data directory ownership is never re-adjusted by tmpfiles" = lib.elem "d /var/lib/circuit-breaker/data - - - -" c.systemd.tmpfiles.rules;
    "every generated unit file renders (no conflicting definitions)" = let
      names = ["podman-circuit-breaker" "circuit-breaker-env" "circuit-breaker-ready" "circuit-breaker-sync" "circuit-breaker-provision" "circuit-breaker-snapshot" "cb-agent"];
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
    in
      lib.all (n: builtins.stringLength full.config.systemd.units."${n}.service".text > 0) (names ++ ["circuit-breaker-sync-git"]) && builtins.stringLength full.config.systemd.units."circuit-breaker-snapshot.timer".text > 0 && builtins.stringLength full.config.environment.etc."circuit-breaker/agent.toml".source > 0;
    "secrets directory never collides with the container unit's RuntimeDirectory" = svc.podman-circuit-breaker.serviceConfig.RuntimeDirectory != svc.circuit-breaker-env.serviceConfig.RuntimeDirectory && !(lib.hasInfix "/${svc.podman-circuit-breaker.serviceConfig.RuntimeDirectory}/" (lib.head cont.environmentFiles));
    "podman: tmpfs mounts opt out of copy-up (image ships 39 MB under /var/lib/postgresql)" = lib.all (o: lib.hasSuffix ",notmpcopyup" o) (lib.filter (lib.hasPrefix "--tmpfs=") cont.extraOptions);
    "docker: tmpfs mounts use plain options" = let
      d = evalWith {
        virtualisation.oci-containers.backend = "docker";
        virtualisation.docker.enable = true;
        fmf.services.circuit-breaker = lib.recursiveUpdate good {};
      };
    in
      lib.all (o: !(lib.hasInfix "notmpcopyup" o)) d.config.virtualisation.oci-containers.containers.circuit-breaker.extraOptions;
    "container waits for the secrets unit" = lib.elem "circuit-breaker-env.service" svc.podman-circuit-breaker.requires && lib.elem "circuit-breaker-env.service" svc.podman-circuit-breaker.after;
    "readiness gate orders after the container" = lib.elem "podman-circuit-breaker.service" svc.circuit-breaker-ready.requires;
    "sync orders after readiness" = lib.elem "circuit-breaker-ready.service" svc.circuit-breaker-sync.after;
    "sync consumes a build-time inventory store path" = lib.hasInfix "--apply --inventory ${builtins.unsafeDiscardStringContext (toString inventorySrc)}" (builtins.unsafeDiscardStringContext syncExec);
    "sync reads the token as a systemd credential, not an argument" = lib.hasInfix "--token-file %d/token" syncExec && lib.any (lib.hasSuffix "/sync-token") svc.circuit-breaker-sync.serviceConfig.LoadCredential && !(lib.hasInfix "sync-token" syncExec);
    "sync pins the server certificate" = lib.hasInfix "--tls-pin-file %d/server-cert" syncExec;
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
    "reject: floating image tag" = rejects "pinned by digest" (mk {server.image = "ghcr.io/blkleg/circuitbreaker:latest";});
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
