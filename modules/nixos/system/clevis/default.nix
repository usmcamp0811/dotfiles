{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.clevis;
in
{
  options.campground.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis.";
  };

  config = mkIf cfg.enable {
    boot.initrd.extraUtilsCommands = ''
        # clevis dependencies
        copy_bin_and_libs ${pkgs.curl}/bin/curl
        copy_bin_and_libs ${pkgs.bash}/bin/bash
        copy_bin_and_libs ${pkgs.jose}/bin/jose

        # clevis scripts and binaries
        for i in ${pkgs.clevis}/bin/* ${pkgs.clevis}/bin/.clevis-wrapped; do
          copy_bin_and_libs "$i"
        done
    '';
    boot.initrd.luks.devices.nixos-root = {
      device = "/dev/disk/by-uuid/${uuid}";
      preOpenCommands = ''
        # what would be a sensible way of automating this? at the very least the versions should not be hard coded
        ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-bash-5.1-p16
        ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-clevis-18
        ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-coreutils-9.0

        # this runs in the background so that /crypt-ramfs/device gets set up, which implies crypt-askpass
        # is ready to receive an input which it will write to /crypt-ramfs/passphrase.
        # for some reason writing that file directly does not seem to work, which is why the pipe is used.
        # the clevis_luks_unlock_device function is equivalent to the clevis-luks-pass command but avoid
        # needing to pass the slot argument.
        # using clevis-luks-unlock directly can successfully open the luks device but requires the name
        # argument to be passed and will not be detected by the stage-1 luks root stuff.
        bash -e -c 'while [ ! -f /crypt-ramfs/device ]; do sleep 1; done; . /bin/clevis-luks-common-functions; clevis_luks_unlock_device "$(cat /crypt-ramfs/device)" | cryptsetup-askpass' &
      '';
    };
  };
}

