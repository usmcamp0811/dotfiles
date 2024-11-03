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
    systemd.services.n8n.path = [
      pkgs.nodejs
      pkgs.nodePackages.npm
    ]; # Add Node.js and npm to the system path for this service

    services.n8n = {
      enable = true;
      webhookUrl = cfg.webhookUrl;
      settings = cfg.settings;
    };

    environment.systemPackages = with pkgs; [ nodejs nodePackages.npm ];
  };
}
