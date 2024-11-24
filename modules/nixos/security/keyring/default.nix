{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.security.keyring;
in {
  options.campground.security.keyring = with types; {
    enable = mkBoolOpt false "Whether to enable gnome keyring.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnome-keyring
      libgnome-keyring
    ];
  };
}
