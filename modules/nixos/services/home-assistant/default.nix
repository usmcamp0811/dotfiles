{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.home-assistant;
  yaml = pkgs.formats.yaml {};
  secretFile = config.fmf.services.vault-agent.services.home-assistant.secrets.file.files."home-assistant-secrets.yaml".path;
in {
  options.fmf.services.home-assistant = with types; {
    enable = mkEnableOption "Home Assistant Core";
    dataDir = mkOpt str "/var/lib/hass" "Home Assistant configuration and state directory; persist this entire directory.";
    port = mkOpt port 8123 "Home Assistant HTTP port.";
    listenAddress = mkOpt str "0.0.0.0" "Home Assistant HTTP listen address.";
    openFirewall = mkBoolOpt false "Open the Home Assistant HTTP port.";
    openFirewallForComponents = mkBoolOpt false "Open additional ports supported by the upstream Home Assistant module.";
    extraComponents = mkOpt (listOf str) ["default_config" "esphome" "met"] "Integrations whose Python dependencies should be installed, including UI-configured integrations.";
    config = mkOpt yaml.type {} "Declarative Home Assistant configuration. Use !secret references, never literal credentials.";
    trustedProxies = mkOpt (listOf str) [] "Explicit trusted reverse-proxy addresses/CIDRs; enables X-Forwarded-For only when non-empty.";

    vault.enable = mkBoolOpt false "Render Vault KV fields as Home Assistant secrets.yaml using the existing Vault Agent sidecar.";
    vault-path = mkOpt str "secret/campground/home-assistant" "Logical Vault KV path (the agent handles the KV v2 data prefix).";
    kvVersion = mkOpt (enum ["v1" "v2"]) "v2" "Vault KV version.";
    role-id = mkOpt str (config.fmf.services.vault-agent.settings.vault.role-id or "/var/lib/vault/home-assistant/role-id") "Absolute path to the Vault AppRole role-id file.";
    secret-id = mkOpt str (config.fmf.services.vault-agent.settings.vault.secret-id or "/var/lib/vault/home-assistant/secret-id") "Absolute path to the Vault AppRole secret-id file.";
    vault-address = mkOpt str (config.fmf.services.vault-agent.settings.vault.address or "https://vault.lan.aicampground.com") "Vault server address.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasPrefix "/" cfg.dataDir;
        message = "fmf.services.home-assistant.dataDir must be an absolute path.";
      }
    ];

    services.home-assistant = {
      enable = true;
      configDir = cfg.dataDir;
      inherit (cfg) extraComponents openFirewall openFirewallForComponents;
      config = mkMerge [
        cfg.config
        {
          default_config = mkDefault {};
          http.server_host = mkDefault cfg.listenAddress;
          http.server_port = mkDefault cfg.port;
          # Preserve UI-created automations, scenes and scripts across restarts.
          automation = mkDefault "!include automations.yaml";
          scene = mkDefault "!include scenes.yaml";
          script = mkDefault "!include scripts.yaml";
        }
        (mkIf (cfg.trustedProxies != []) {
          http.use_x_forwarded_for = true;
          http.trusted_proxies = cfg.trustedProxies;
        })
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 hass hass -"
    ];
    systemd.services.home-assistant = {
      unitConfig.RequiresMountsFor = [cfg.dataDir];
      preStart = mkBefore (''
        ${pkgs.coreutils}/bin/mkdir -p ${escapeShellArg "${cfg.dataDir}/blueprints"}
        # Only initialize missing files; never replace UI-created content.
        for name in automations scenes; do
          if [ ! -e ${escapeShellArg cfg.dataDir}/"$name.yaml" ]; then
            ${pkgs.coreutils}/bin/install -m 0600 ${pkgs.writeText "home-assistant-empty-list.yaml" "[]\n"} ${escapeShellArg cfg.dataDir}/"$name.yaml"
          fi
        done
        if [ ! -e ${escapeShellArg "${cfg.dataDir}/scripts.yaml"} ]; then
          ${pkgs.coreutils}/bin/install -m 0600 ${pkgs.writeText "home-assistant-empty-map.yaml" "{}\n"} ${escapeShellArg "${cfg.dataDir}/scripts.yaml"}
        fi
      '' + optionalString cfg.vault.enable ''
        # The service and its Vault sidecar share PrivateTmp. No secret values
        # enter the Nix store or a persistent copy of secrets.yaml.
        test -s ${escapeShellArg secretFile}
        ${pkgs.coreutils}/bin/ln -sfn ${escapeShellArg secretFile} ${escapeShellArg "${cfg.dataDir}/secrets.yaml"}
      '');
    };

    fmf.services.vault-agent = mkIf cfg.vault.enable {
      enable = true;
      services.home-assistant = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth.method = [
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
        secrets.file.files."home-assistant-secrets.yaml" = {
          # JSON is valid YAML and safely quotes arbitrary credential values.
          text = ''
            {{ with secret "${cfg.vault-path}" }}{{ ${if cfg.kvVersion == "v2" then ".Data.data" else ".Data"} | toJSON }}{{ end }}
          '';
          permissions = "0600";
          change-action = "restart";
        };
      };
    };
  };
}
