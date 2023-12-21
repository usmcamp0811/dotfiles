{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.hydra;
in
{
  options.campground.services.hydra = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 6956 "Port to Host the hydra server on.";
    # role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    # secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    # vault-path = mkOpt str "secret/campground/hydra" "The Vault path to the KV containing the Searx Secrets.";
    # kvVersion = mkOption {
    #   type = enum ["v1" "v2"];
    #   default = "v2";
    #   description = "KV store version";
    # };
    # vault-address = mkOption {
    #   type = str;
    #   default = config.campground.services.vault-agent.settings.vault.address;
    #   description = "The address of your Vault";
    # };
  };

  config = mkIf cfg.enable {
    services.hydra = {
      enable = true;
      hydraURL = "http://127.0.0.1:9842";
      notificationSender = "hydra@aicampground.com";
      buildMachinesFiles = [];
      useSubstitutes = true;
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
          "hydra.lan" = {
          listen = [ { addr = "0.0.0.0"; port = cfg.port; } ];  # Specify the port here
          http2 = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:9842";
            proxyWebsockets = true;
          };
        };
      };
    };
  };
}
