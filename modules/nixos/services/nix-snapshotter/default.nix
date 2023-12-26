{ inputs, lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.nix-snapshotter;
  
  preloadContainerdImages = [pkgs.campground.containers];
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
      # preloadContainerdImages = preloadContainerdImages;
      inherit preloadContainerdImages;
    };


    environment.systemPackages = with pkgs; [ 
        containerd
        cri-tools
        delve
        gdb
        golangci-lint
        gopls
        gotools
        kind
        kubectl
        redis
        rootlesskit
        runc
        slirp4netns
        nerdctl
    ];

  };
}
