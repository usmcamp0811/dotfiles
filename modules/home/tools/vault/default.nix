{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.vault;
in {
  options.campground.tools.vault = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Vault CLI.";
    vault-addr =
      mkOpt str "https://vault.lan.aicampground.com" "url for the vault";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ vault consul ];
    home.sessionVariables = { VAULT_ADDR = cfg.vault-addr; };
  };
}
