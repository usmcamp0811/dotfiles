{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.zfs;
in
{
  options.campground.system.zfs = with types; {
    enable = mkBoolOpt false "Whether or not to configure zfs.";
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      clevis
    ];

    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.requestEncryptionCredentials = true;
    services.zfs.autoScrub.enable = true;

    networking.hostId = cfg.hostId;

    boot.initrd.network = {
      enable = true;
      postCommands = ''
        zpool import -a;
        echo $(curl http::/ata-xps:8080/zfs-keyfile) | zfs load-key -a && killall zfs
      '';
      ssh = {
        enable = true;
        port = 22;
        authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler" ];
        hostKeys = [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];

      };
    };
    # networking.useDHCP = lib.mkForce true;
    # use this lspci -v | grep -iA8 'network\|ethernet' to then ask Chad what modules to use here
    boot.initrd.availableKernelModules = [ "iwlwifi" "igc" "cdc_ether" ];
    boot.kernelParams = [ "ip=dhcp" ];
    boot.kernelModules = [ "r8169" "cdc_ether" ];
    boot.initrd.kernelModules = [ "r8169" "cdc_ether" ];
    # boot.kernelModules = [ "iwlwifi" "cdc_ether" ];
    # boot.initrd.kernelModules = [ "iwlwifi" "cdc_ether" ];
  };

}
