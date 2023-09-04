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
    # Phase 1 NFS mount
    boot.initrd.network = {
      enable = true;
      postCommands = ''
        mkdir -p /mnt/campfs
        mount -t nfs -o vers=4 10.8.0.140:/mnt/campfs /mnt/campfs
      '';
      ssh = {
        enable = true;
        port = 22;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler" ];
        hostKeys = [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];

      };
    };
    # TODO: This should probably be parameterized and or not here because it could vary per system
    # use this lspci -v | grep -iA8 'network\|ethernet' to then ask Chad what modules to use here
    boot.initrd.availableKernelModules = [ "iwlwifi" "igc" "nfsv4" ];
    boot.kernelParams = [ "ip=dhcp" ];
  };
}

