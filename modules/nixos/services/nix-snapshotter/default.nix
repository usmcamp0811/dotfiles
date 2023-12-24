{ inputs, lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.nix-snapshotter;
in
{
  imports = [
    inputs.nix-snapshotter.nixosModules.default
  ];

  options.campground.services.nix-snapshotter = with types; {
    enable = mkBoolOpt false "Enable Nix Snapshotter;";
  };

  config = mkIf cfg.enable {

    services.nix-snapshotter = {
      enable = true;
      setContainerdSnapshotter = true;
    };

    environment.systemPackages = [ pkgs.nerdctl pkgs.hello-nix ];

  };
}
