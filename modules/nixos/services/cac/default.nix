{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.cac;
in {
  options.campground.services.cac = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ pcsclite opensc ccid ];

    services.pcscd.enable = true;

  };
}
