{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.vault;
in
{
  options.campground.tools.vault = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Vault CLI.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      vault
    ];
  };
}
