{ pkgs, lib, config, ... }:
with lib;
with lib.campground;
let
  # TODO: One day maybe pass credentials automatically into n8n via Vault
  cfg = config.campground.services.n8n;
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
      type = attrsOf str;
      default = {
        N8N_COMMUNITY_NODES_ENABLED = "true"; # Enables community nodes
        N8N_NODES_EXCLUDE = ""; # Leave blank to include all nodes
        N8N_NODES_INCLUDE = ""; # Leave blank to include all nodes
        N8N_DEFAULT_TIMEOUT =
          "120"; # Default timeout for node operations in seconds
        N8N_PERSONALIZATION_ENABLED =
          "false"; # Disables personalization analytics (optional)
      };
      description =
        "Additional configuration settings for n8n, passed as environment variables. For supported values, see https://docs.n8n.io/hosting/environment-variables/configuration-methods/";
    };
  };

  config = mkIf cfg.enable {
    services.n8n = {
      enable = true;
      webhookUrl = cfg.webhookUrl;
      settings = cfg.settings;
    };

    environment.systemPackages = with pkgs; [ nodejs nodePackages.npm ];
  };
}
