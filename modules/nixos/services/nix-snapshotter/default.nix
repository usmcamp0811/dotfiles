{ inputs, lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.nix-snapshotter;

  # preloadContainerdImages = [pkgs.campground.containers];
  preloadContainerdImages = [ ];
in {
  imports = [ inputs.nix-snapshotter.nixosModules.default ];

  options.campground.services.nix-snapshotter = with types; {
    enable = mkBoolOpt false "Enable Nix Snapshotter;";
  };

  config = mkIf cfg.enable {

    virtualisation.containerd = {
      enable = true;
      nixSnapshotterIntegration = true;
    };
    services.nix-snapshotter = { enable = true; };

    environment.systemPackages = [ pkgs.nerdctl ];

  };
}
