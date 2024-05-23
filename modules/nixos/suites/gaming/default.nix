{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.gaming;
in {
  options.campground.suites.gaming = with types; {
    enable = mkBoolOpt false "Whether or not to enable gaming configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      [ pkgs.lutris pkgs.steam pkgs.prismlauncher pkgs.mangohud ];
  };
}
