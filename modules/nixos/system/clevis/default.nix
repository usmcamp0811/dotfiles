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

    environment.systemPackages = with pkgs; [
      clevis
    ];
    # boot.initrd = {
    #   preLVMCommands = ''
    #     ${pkgs.curl}/bin/curl http://10.8.0.127:1234/adv > /dev/console
    #   '';
    # };
    # Phase 1 NFS mount
    boot.initrd.network = {
      enable = true;
      postCommands = ''
        mkdir -p /mnt/campfs
        mount -t nfs -o vers=4 10.8.0.140:/mnt/campfs /mnt/campfs
        sleep 10
        ls -lah /mnt/campfs
      '';
      ssh = {
        enable = true;
        port = 22;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler" ];
        hostKeys = [ "/home/mcamp/.ssh/id_ed25519" ];
      };
    };
    boot.initrd.availableKernelModules = [ "iwlwifi" "igc" "nfsv4" ];

    boot.kernelParams = [ "ip=dhcp" ];
    # boot.initrd.network.postCommands = ''
    #   ip addr add 10.8.0.2/24 dev eth0
    #   ip route add default via 10.8.0.1
    #   echo "nameserver 8.8.8.8" > /etc/resolv.conf
    #
    #   mkdir -p /mnt/campfs
    #   mount -t nfs 10.8.0.140:/mnt/campfs /mnt/campfs
    # '';
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

    # boot.initrd.luks.devices.luks = {
    #   preOpenCommands = ''
    #     # what would be a sensible way of automating this? at the very least the versions should not be hard coded
    #     ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-bash-5.1-p16
    #     ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-clevis-18
    #     ln -s ../.. /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-coreutils-9.0
    #
    #     # this runs in the background so that /crypt-ramfs/device gets set up, which implies crypt-askpass
    #     # is ready to receive an input which it will write to /crypt-ramfs/passphrase.
    #     # for some reason writing that file directly does not seem to work, which is why the pipe is used.
    #     # the clevis_luks_unlock_device function is equivalent to the clevis-luks-pass command but avoid
    #     # needing to pass the slot argument.
    #     # using clevis-luks-unlock directly can successfully open the luks device but requires the name
    #     # argument to be passed and will not be detected by the stage-1 luks root stuff.
    #     bash -e -c 'while [ ! -f /crypt-ramfs/device ]; do sleep 1; done; . /bin/clevis-luks-common-functions; clevis_luks_unlock_device "$(cat /crypt-ramfs/device)" | cryptsetup-askpass' &
    #   '';
    # };
    # # LUKS root filesystem
    # boot.initrd.luks.devices = [{
    #   name = "root";
    #   device = "/dev/disk/by-uuid/your-uuid-here";
    #   preLVM = true;
    #   keyFile = "/mnt/campfs/luks-keyfile";
    # }];
    # };
  };
}

