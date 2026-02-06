{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.apps.virtualbox;
in {
  options.fmf.apps.virtualbox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virtualbox.";
  };

  config = mkIf cfg.enable {
    virtualisation.virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
      headless = true;
    };
    virtualisation.virtualbox.guest.enable = true;
    fmf.user.extraGroups = [ "vboxusers" ];
    environment.systemPackages = [ pkgs.virtualbox ];
  };
}
