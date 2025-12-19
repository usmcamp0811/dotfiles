{ lib
, config
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.hydra;
in
{
  options.fmf.services.hydra = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 6956 "Port to Host the hydra server on.";
    # role-id = mkOpt str config.fmf.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    # secret-id = mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    # vault-path = mkOpt str "secret/campground/hydra" "The Vault path to the KV containing the Searx Secrets.";
    # kvVersion = mkOption {
    #   type = enum ["v1" "v2"];
    #   default = "v2";
    #   description = "KV store version";
    # };
    # vault-address = mkOption {
    #   type = str;
    #   default = config.fmf.services.vault-agent.settings.vault.address;
    #   description = "The address of your Vault";
    # };
  };

  config = mkIf cfg.enable {
    services.hydra = {
      enable = true;
      port = cfg.port;
      hydraURL = "https://hydra.lan.aicampground.com";
      notificationSender = "hydra@aicampground.com";
      buildMachinesFiles = [ ];
      useSubstitutes = true;
    };
  };
}
