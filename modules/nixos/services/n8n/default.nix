{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
with lib.fmf; let
  # TODO: One day maybe pass credentials automatically into n8n via Vault
  cfg = config.fmf.services.n8n;
  format = pkgs.formats.json {};
  configFile = format.generate "n8n.json" cfg.settings;
in {
  options.fmf.services.n8n = with types; {
    enable = mkBoolOpt false "Enable n8n.";
    port = mkOpt int cfg.settings.port "Port for n8n";
    webhookUrl = mkOption {
      type = str;
      default = "";
      description = "WEBHOOK_URL for n8n, in case we’re running behind a reverse proxy. This cannot be set through configuration and must reside in an environment variable.";
    };
    settings = mkOption {
      type = format.type;
      default = {
        generic = {timezone = config.time.timeZone;};
        endpoints = {metrics = {enable = true;};};
        port = 5678;
        # community = { nodes = { enable = true; }; };
      };

      description = "Additional configuration settings for n8n, passed as environment variables. For supported values, see https://docs.n8n.io/hosting/environment-variables/configuration-methods/";
    };
  };

  config = mkIf cfg.enable {
    services.n8n = {
      enable = true;
      environment = {
        WEBHOOK_URL = mkIf (cfg.webhookUrl != "") cfg.webhookUrl;
        N8N_PORT = toString cfg.port;
        GENERIC_TIMEZONE = config.time.timeZone;
        N8N_METRICS_ENABLE = "true";
      };
    };
    environment.systemPackages = with pkgs; [nodejs nodePackages.npm];
  };
}
