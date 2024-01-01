{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.zfs;
in
{
  options.campground.system.zfs = with types; {
    enable = mkBoolOpt false "Whether or not to configure zfs.";
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
    keyfile-url = mkOpt str "http://key-server:8080/zfs-keyfile" "The URL for the Clevis encrypted Keyfile";
    public_keys = mkOpt (lib.types.listOf lib.types.str) [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler" ] "List of public ssh keys to access the Phase 1 Boot for remote unlocking of ZFS";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      clevis
    ];

    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.requestEncryptionCredentials = true;
    services.zfs.autoScrub.enable = true;
    services.nfs.server.enable = true;


    networking.hostId = cfg.hostId;

    boot.initrd.network = {
      enable = true;
      postCommands = ''
        sleep 2
        export PATH="${pkgs.curl}/bin:${pkgs.clevis}/bin:$PATH"
        zpool import -a;

        # Retrieve and decrypt the passphrase
        PASSPHRASE=$(echo $(${pkgs.curl}/bin/curl -s ${cfg.keyfile-url}) | ${pkgs.clevis}/bin/clevis decrypt)

        # Load the key for each ZFS pool
        for pool in $(zpool list -H -o name)
        do
            echo $PASSPHRASE | zfs load-key $pool
        done

        killall zfs
      '';
      ssh = {
        enable = true;
        port = 22;
        authorizedKeys = cfg.public_keys;
        # TODO: Do somehting to make sure these keys exist. Currently wont exist until you ssh somewhere for the first time.
        hostKeys = [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };
    # use this lspci -v | grep -iA8 'network\|ethernet' to then ask Chad what modules to use here
    boot.initrd.availableKernelModules = [  "thunderbolt" "usbnet" "igb" "r8152" "iwlwifi" "igc" "cdc_ether" ];
    boot.kernelParams = [ "ip=dhcp" ];
    boot.kernelModules = [ "e1000e" "alx" "r8169" "igb" "cdc_ether" "r8152" ];
    boot.initrd.kernelModules = [ "e1000e" "alx" "r8169" "igb" "cdc_ether" "r8152" ];

    # TODO: Move this somewhere more appropriate or otherwise fix dns
    networking.useDHCP = mkForce true;

    services.zfs.autoSnapshot = {
      enable = true;
    };
  };

}
