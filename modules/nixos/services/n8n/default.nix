{ pkgs, lib, config, ... }:
with lib;
with lib.campground;
let
  # TODO: One day maybe pass credentials automatically into n8n via Vault
  cfg = config.campground.services.n8n;
  format = pkgs.formats.json { };
  configFile = format.generate "n8n.json" cfg.settings;
  cfg.setting.port = mkForce cfg.port;
in
{
  options.campground.services.n8n = with types; {
    enable = mkBoolOpt false "Enable n8n.";
    port = mkOpt int 5678 "Port for n8n";
    webhookUrl = mkOption {
      type = str;
      default = "";
      description =
        "WEBHOOK_URL for n8n, in case we’re running behind a reverse proxy. This cannot be set through configuration and must reside in an environment variable.";
    };
    settings = mkOption {
      type = format.type;
      default = {
        generic = { timezone = config.time.timeZone; };
        endpoints = { metrics = { enable = true; }; };
        # community = { nodes = { enable = true; }; };
      };

      description =
        "Additional configuration settings for n8n, passed as environment variables. For supported values, see https://docs.n8n.io/hosting/environment-variables/configuration-methods/";
    };
  };

  config = mkIf cfg.enable {

    # systemd.services.n8n = {
    #   description = "N8N service";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   path = [ pkgs.nodejs pkgs.nodePackages.npm pkgs.coreutils pkgs.bash ];
    #   environment = {
    #     # This folder must be writeable as the application is storing
    #     # its data in it, so the StateDirectory is a good choice
    #     N8N_USER_FOLDER = "/var/lib/n8n";
    #     N8N_CONFIG_FILES = "${configFile}";
    #     N8N_COMMUNITY_NODES_ENABLED = "true";
    #     NPM_CONFIG_PREFIX = "/var/lib/n8n/.npm-global";
    #     NPM_CONFIG_CACHE = "/var/lib/n8n/.npm";
    #     HOME = "/var/lib/n8n";
    #     N8N_LOG_LEVEL = "debug";
    #     NODE_FUNCTION_ALLOW_EXTERNAL = "*";
    #     NODES_INCLUDE = ''["n8n-nodes-ai"]'';
    #   };
    #   script = ''
    #     export NPM_CONFIG_CACHE=/var/lib/n8n/.npm
    #     export NPM_CONFIG_PREFIX=/var/lib/n8n/.npm-global
    #     export HOME=/var/lib/n8n
    #     export NODE_ENV=production
    #     mkdir -p /var/lib/n8n/.npm-global
    #     mkdir -p /var/lib/n8n/.npm
    #     mkdir -p /var/lib/n8n/.n8n
    #
    #     exec ${pkgs.n8n}/bin/n8n
    #   '';
    #   serviceConfig = {
    #     Type = "simple";
    #     Restart = "on-failure";
    #     StateDirectory = "n8n";
    #
    #     # # Basic Hardening
    #     # NoNewPrivileges = "yes";
    #     # PrivateTmp = "yes";
    #     # PrivateDevices = "yes";
    #     # DevicePolicy = "closed";
    #     # DynamicUser = "true";
    #     # ProtectSystem = "strict";
    #     # ProtectHome = "read-only";
    #     # ProtectControlGroups = "yes";
    #     # ProtectKernelModules = "yes";
    #     # ProtectKernelTunables = "yes";
    #     # RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
    #     # RestrictNamespaces = "yes";
    #     # RestrictRealtime = "yes";
    #     # RestrictSUIDSGID = "yes";
    #     # MemoryDenyWriteExecute =
    #     #   "no"; # v8 JIT requires memory segments to be Writable-Executable.
    #     # LockPersonality = "yes";
    #   };
    # };

    # networking.firewall =
    #   mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.settings.port ]; };

    # users.users.n8n = {
    #   isNormalUser = false;
    #   isSystemUser = true;
    #   description = "N8N System User";
    #   group = "n8n";
    #   extraGroups =
    #     [ "n8n" ]; # Optional if you want the user to be in additional groups
    #   home = "/var/lib/n8n";
    # };
    # users.groups.labelstudio = { };

    services.n8n = {
      enable = true;
      webhookUrl = cfg.webhookUrl;
      settings = cfg.settings;
    };

    environment.systemPackages = with pkgs; [ nodejs nodePackages.npm ];
  };
}
