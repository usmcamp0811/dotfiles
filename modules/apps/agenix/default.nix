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
    mkIf cfg.enable { 
      environment.systemPackages = [ 
        (pkgs.callPackage (builtins.fetchTarball {
          url = "https://github.com/ryantm/agenix/archive/main.tar.gz";
          sha256 = "0x3d45zcqpai6jr3d68jhl2vcwavyflvrh7iksk3ppqpv6m0sy2s";
        } + "/pkgs/agenix.nix") {})
      ]; 
    };
}
