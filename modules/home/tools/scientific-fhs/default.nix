{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.scientific-fhs;
in
{
  options.campground.tools.scientific-fhs = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Julia.";
  };

  config = mkIf cfg.enable {

    programs.scientific-fhs = {
      enable = true;
      juliaVersions = [
        {
          version = "julia_18";
          default = true;
        }
        { version = "julia_17"; }
        { version = "julia_16"; }
      ];
      enableNVIDIA = false;
    };
  };
}
