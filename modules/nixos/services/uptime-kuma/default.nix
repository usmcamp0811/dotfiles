{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.uptime-kuma;
  pcfg = cfg.provision;

  # Must match the systemd unit name: nixos-vault-service only attaches its sidecar (and the shared
  # PrivateTmp the secrets are rendered into) to a unit whose name equals the vault-agent service name.
  unitName = "uptime-kuma-provision";
  vaultDir = "/tmp/detsys-vault";
  usesVault = pcfg.usernameFile == null || pcfg.passwordFile == null;

  vaultSecretTemplate = field: ''
    {{ with secret "${pcfg.vault-path}" }}{{ if eq "${pcfg.kvVersion}" "v1" }}{{ .Data.${field} }}{{ else }}{{ .Data.data.${field} }}{{ end }}{{ end }}
  '';

  discovered = import ./traefik.nix {inherit lib;} {
    inherit (cfg.traefik) nixosConfigurations hosts httpsEntryPoints;
  };

  # Monitor option -> the field names Kuma's API uses. Nulls are dropped so Kuma keeps its defaults.
  toKuma = m:
    filterAttrs (_: v: v != null) {
      inherit (m) name type url hostname port interval retryInterval maxretries ignoreTls description;
      accepted_statuscodes = m.acceptedStatusCodes;
    }
    // m.settings;

  monitorsFile = pkgs.writeText "uptime-kuma-monitors.json" (builtins.toJSON (mapAttrs (_: toKuma) cfg.monitors));

  kumaModules = "${config.services.uptime-kuma.package}/lib/node_modules/uptime-kuma/node_modules";

  # Read-only preview: the same reconciler and monitor list, KUMA_DRY_RUN forced on. Credentials
  # come from KUMA_USERNAME_FILE / KUMA_PASSWORD_FILE (see the runbook).
  planScript = pkgs.writeShellScriptBin "uptime-kuma-plan" ''
    : "''${KUMA_USERNAME_FILE:?set KUMA_USERNAME_FILE (see the uptime-kuma runbook)}"
    : "''${KUMA_PASSWORD_FILE:?set KUMA_PASSWORD_FILE}"
    export NODE_PATH=${kumaModules}
    export KUMA_URL=''${KUMA_URL:-http://127.0.0.1:${toString cfg.port}}
    export KUMA_MONITORS_FILE=${monitorsFile} KUMA_TAG=${escapeShellArg pcfg.tag} KUMA_DRY_RUN=1
    exec ${pkgs.nodejs}/bin/node ${./provision.js}
  '';

  monitorType = types.submodule ({name, ...}: {
    options = with types; {
      name = mkOpt str name "Display name in Uptime Kuma. Defaults to the monitor's key.";
      type = mkOpt str "http" "Kuma monitor type (http, keyword, port, ping, dns, ...).";
      url = mkOpt (nullOr str) null "URL for http/keyword monitors.";
      hostname = mkOpt (nullOr str) null "Host for port/ping/dns monitors.";
      port = mkOpt (nullOr port) null "Port for port monitors.";
      interval = mkOpt int 60 "Seconds between checks.";
      retryInterval = mkOpt int 60 "Seconds between checks while a monitor is failing.";
      maxretries = mkOpt int 2 "Failed checks in a row before the monitor is marked down.";
      acceptedStatusCodes = mkOpt (listOf str) ["200-299"] "HTTP status codes (or ranges) that count as up.";
      ignoreTls = mkBoolOpt false "Do not verify the TLS certificate.";
      description = mkOpt (nullOr str) null "Description shown in Uptime Kuma.";
      settings = mkOpt attrs {} "Raw Kuma monitor fields merged over the ones above (escape hatch).";
    };
  });
in {
  options.fmf.services.uptime-kuma = with types; {
    enable = mkBoolOpt false "Enable Uptime Kuma.";
    port = mkOpt int 4000 "Port to host the Uptime Kuma server on.";
    openFirewall = mkBoolOpt true "Open the port on every interface. Turn off to open it on chosen interfaces yourself (networking.firewall.interfaces.<if>.allowedTCPPorts).";

    monitors = mkOption {
      type = attrsOf monitorType;
      default = {};
      example = literalExpression ''
        {
          "lan/grafana" = { url = "https://grafana.example.lan"; acceptedStatusCodes = ["200-399"]; };
          "nas-ssh" = { type = "port"; hostname = "192.168.50.20"; port = 22; };
        }
      '';
      description = ''
        Monitors managed declaratively. The attribute name is the monitor's identity: the provisioner
        tags each monitor it creates with it, edits it when its fields change, and deletes it when the
        attribute goes away. Monitors created in the UI (no tag) are never touched.
      '';
    };

    traefik = {
      enable = mkBoolOpt false ''
        Add one HTTP monitor per enabled Traefik router of the hosts in `hosts` (see ./traefik.nix for
        what counts as a router and as enabled). Keys are `<label>/<router>`.
      '';
      hosts = mkOpt (attrsOf str) {} ''
        Label -> nixosConfiguration name whose `services.traefik.dynamicConfigOptions` is read,
        e.g. `{ lan = "lan-proxy"; public = "public-proxy"; }`.
      '';
      # No default on purpose: inside a module exported from fmf, `inputs.self` is fmf itself, not the
      # flake that imports it, so a default would silently read fmf's example hosts.
      nixosConfigurations = mkOption {
        type = attrs;
        default = {};
        example = literalExpression "inputs.self.nixosConfigurations";
        description = "The consuming flake's nixosConfigurations, where the hosts in `hosts` are looked up. Required.";
      };
      httpsEntryPoints = mkOpt (listOf str) ["websecure"] "Entry points served over HTTPS (others are checked over HTTP).";
      exclude = mkOpt (listOf str) [] "Discovered monitor keys (`<label>/<router>`) to leave out.";
      acceptedStatusCodes =
        mkOpt (listOf str) ["200-299" "300-399" "401" "403"]
        "Status codes that count as up for discovered monitors. 401/403: the service answered, it just wants a login.";
      interval = mkOpt int 60 "Seconds between checks for discovered monitors.";
    };

    provision = {
      enable = mkOption {
        type = bool;
        default = cfg.monitors != {};
        defaultText = literalExpression "config.fmf.services.uptime-kuma.monitors != {}";
        description = "Reconcile `monitors` into the running Uptime Kuma (the uptime-kuma-provision unit).";
      };
      tag = mkOpt str "nix" "Name of the Kuma tag that marks managed monitors. Changing it orphans the old ones.";

      usernameFile = mkOpt (nullOr path) null "Admin username file, bypassing Vault (both files must be set to bypass).";
      passwordFile = mkOpt (nullOr path) null "Admin password file, bypassing Vault.";

      vault-path = mkOpt str "secret/campground/uptime-kuma" "Vault KV path holding the Kuma admin credentials.";
      usernameField = mkOpt str "username" "Field in vault-path holding the admin username.";
      passwordField = mkOpt str "password" "Field in vault-path holding the admin password.";
      kvVersion = mkOption {
        type = enum ["v1" "v2"];
        default = "v2";
        description = "Vault KV store version.";
      };
      role-id = mkOpt str config.fmf.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id.";
      secret-id = mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id.";
      vault-address = mkOpt str config.fmf.services.vault-agent.settings.vault.address "Vault server address.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.uptime-kuma = {
        enable = true;
        appriseSupport = true;
        settings = {
          PORT = "${toString cfg.port}";
          HOST = "0.0.0.0";
        };
      };

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
    }

    (mkIf cfg.traefik.enable {
      assertions = [
        {
          assertion = cfg.traefik.nixosConfigurations != {};
          message = "fmf.services.uptime-kuma.traefik.nixosConfigurations must be set (usually inputs.self.nixosConfigurations of your flake).";
        }
      ];
      # mkDefault per field, so a hand-written monitor with the same key can override any of them.
      fmf.services.uptime-kuma.monitors =
        mapAttrs (_: m:
          mapAttrs (_: mkDefault) (m
            // {
              inherit (cfg.traefik) acceptedStatusCodes interval;
            }))
        (removeAttrs discovered cfg.traefik.exclude);
    })

    (mkIf pcfg.enable {
      assertions = [
        {
          assertion = all (m: m.url != null || m.hostname != null) (attrValues cfg.monitors);
          message = "fmf.services.uptime-kuma.monitors: every monitor needs a url or a hostname.";
        }
      ];

      environment.systemPackages = [planScript];

      # Type=simple, not oneshot: activation does not wait for (or fail on) provisioning, so a slow
      # Kuma start or an unreachable Vault cannot roll back a deploy. Restart=on-failure keeps
      # retrying; RemainAfterExit lets a changed monitor list (restartTriggers) re-run it on switch.
      # PartOf: when Kuma restarts, the monitors are re-applied.
      systemd.services.${unitName} = {
        description = "Reconcile declarative Uptime Kuma monitors";
        after = ["uptime-kuma.service"];
        requires = ["uptime-kuma.service"];
        partOf = ["uptime-kuma.service"];
        wantedBy = ["multi-user.target" "uptime-kuma.service"];
        restartTriggers = [monitorsFile];
        unitConfig.StartLimitIntervalSec = 0;
        environment = {
          NODE_PATH = kumaModules;
          KUMA_URL = "http://127.0.0.1:${toString cfg.port}";
          KUMA_MONITORS_FILE = monitorsFile;
          KUMA_TAG = pcfg.tag;
          KUMA_USERNAME_FILE =
            if usesVault
            then "${vaultDir}/kuma-username"
            else toString pcfg.usernameFile;
          KUMA_PASSWORD_FILE =
            if usesVault
            then "${vaultDir}/kuma-password"
            else toString pcfg.passwordFile;
        };
        serviceConfig = {
          Type = "simple";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "2min";
          ExecStart = "${pkgs.nodejs}/bin/node ${./provision.js}";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
        };
      };

      # Bound the sidecar's wait so a Vault problem cannot hold up a switch or boot.
      systemd.services."detsys-vaultAgent-${unitName}" = mkIf usesVault {
        serviceConfig.TimeoutStartSec = "60s";
      };

      fmf.services.vault-agent.services.${unitName} = mkIf usesVault {
        settings = {
          vault.address = pcfg.vault-address;
          auto_auth.method = [
            {
              type = "approle";
              config = {
                role_id_file_path = pcfg.role-id;
                secret_id_file_path = pcfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
        # The provisioner reads the files on each run, so a rotated password needs no restart.
        secrets.file = {
          change-action = "none";
          files = {
            "kuma-username".text = vaultSecretTemplate pcfg.usernameField;
            "kuma-password".text = vaultSecretTemplate pcfg.passwordField;
          };
        };
      };
    })
  ]);
}
