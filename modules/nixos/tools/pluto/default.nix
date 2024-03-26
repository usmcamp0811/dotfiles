{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.pluto;
in {
  options.campground.tools.pluto = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Pluto.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ campground.pluto ];
  };
}
