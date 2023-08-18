{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.julia;
in
{
  options.campground.tools.julia = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Julia.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      julia
    ];
  };
}
