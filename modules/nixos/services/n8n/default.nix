{ pkgs, lib, config, ... }:
with lib;
with lib.campground;
let
  # TODO: One day maybe pass credentials automatically into n8n via Vault
  cfg = config.campground.services.n8n;
  format = pkgs.formats.json { };
in {
  options.campground.services.n8n = with types; {
    enable = mkBoolOpt false "Enable n8n.";

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
    systemd.services.n8n.environment.N8N_COMMUNITY_NODES_ENABLED = "true";
    systemd.services.n8n.environment.NPM_CONFIG_PREFIX =
      "/var/lib/n8n/.npm-global";
    systemd.services.n8n.environment.NPM_CONFIG_CACHE = "/var/lib/n8n/.npm";
    systemd.services.n8n.environment.HOME = "/var/lib/n8n";
    systemd.services.n8n.environment.N8N_LOG_LEVEL = "debug";
    systemd.services.n8n.environment.NODE_FUNCTION_ALLOW_EXTERNAL = "*";
    systemd.services.n8n.environment.NODES_INCLUDE = ''["n8n-nodes-ai"]'';
    systemd.services.n8n.serviceConfig = { User = "n8n"; };

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
    systemd.services.n8n.path = [
      pkgs.nodejs
      pkgs.nodePackages.npm
      pkgs.coreutils
    ]; # Add Node.js and npm to the system path for this service

    services.n8n = {
      enable = true;
      webhookUrl = cfg.webhookUrl;
      settings = cfg.settings;
    };

    environment.systemPackages = with pkgs; [ nodejs nodePackages.npm ];
  };
}
