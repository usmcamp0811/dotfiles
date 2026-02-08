{ inputs, lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.nix-snapshotter;

  # preloadContainerdImages = [pkgs.fmf.containers];
in {
  imports = [ inputs.nix-snapshotter.nixosModules.default ];

  options.fmf.services.nix-snapshotter = with types; {
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
