{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.gbar;
in
{
  options.campground.desktop.addons.gbar = with types; {
    enable =
      mkBoolOpt false "Whether to enable gBar in the desktop environment.";
  };

  config = mkIf cfg.enable {
    programs.gBar = {
        enable = true;
        config = {
            Location = "L";
            EnableSNI = true;
            SNIIconSize = {
                Discord = 26;
                OBS = 23;
            };
            WorkspaceSymbols = [ " " " " ];
        };
    };
  };
}

