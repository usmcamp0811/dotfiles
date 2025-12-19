{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.virtmanager;
in {
  options.fmf.apps.virtmanager = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virt-manager.";
  };

  config = mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
    environment.systemPackages = with pkgs; [
      spice
      win-spice
      virt-manager
      spice-gtk
    ];

    # Ensuring dconf is enabled
    programs.dconf.enable = true;
  };
}
