{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.apps.agenix;
  # agenix = {
    # url = "github:yaxitech/ragenix";
    # flake = false;
  # };
  agenix.url = "github:yaxitech/ragenix";
in
{
  options.campground.apps.agenix = with types; {
    enable = mkBoolOpt false "Whether or not to enable agenix.";
  };

  # TODO: use the rust version and also do the other way not this way.. that uses the github repo
  config =
    mkIf cfg.enable { 
      environment.systemPackages = [ 
        # (pkgs.callPackage (builtins.fetchTarball {
        #   url = "https://github.com/yaxitech/ragenix/archive/main.tar.gz";
        #   sha256 = "1j9yr5q0453wnmn8941vfppwfsqmx98nk1ajqqw4zjgmkc0kjfbn";
        # } + "/pkgs/agenix.nix") {})
        agenix.nixosModules.default
      ]; 
    };
}
