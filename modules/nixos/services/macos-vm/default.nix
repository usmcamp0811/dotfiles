{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.macos-vm;
  inherit (pkgs.campground) mlflow;
in
{
  options.campground.services.macos-vm = with types; {
    enable = mkBoolOpt false "Enable an MacOS VM;";
    sshPort = mkOpt int 2233 "ssh Port to use for VM";
    extraQemuFlags = mkOpt (listOf str) [ ] "Extra Flags for QEMU";
    diskSizeBytes = mkOpt int 120000000000 "Size of disk image in bytes";
  };

  config = mkIf cfg.enable {
    users.users.macos-ventura = {
      isSystemUser = true;
      group = "macos-ventura";
    };
    users.groups.macos-ventura = { };

    campground.nix.additional-authorized-users = [ "macos-ventura" ];
    services.macos-ventura = {
      enable = true;
      package = pkgs.makeDarwinImage { diskSizeBytes = cfg.diskSizeBytes; };
      openFirewall = true;
      sshPort = cfg.sshPort;
      vncListenAddr = "0.0.0.0";
      extraQemuFlags =
        [ "-device usb-host,vendorid=0x05ac,productid=0x12a8" ]
        ++ cfg.extraQemuFlags;
    };
  };
}
