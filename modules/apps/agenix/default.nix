{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.apps.agenix;
  agenix = {
    url = "github:yaxitech/ragenix";
    flake = false;
  };
in
{
  options.campground.apps.agenix = with types; {
    enable = mkBoolOpt false "Whether or not to enable agenix.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ agenix.packages.${system}.default ]; };
}
