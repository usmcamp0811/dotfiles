{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.clevis;
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis.";
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
    keyfile-url =
      mkOpt str "http://key-server:8080/zfs-keyfile"
      "The URL for the Clevis encrypted Keyfile";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis];
    # Phase 1 NFS mount
    boot.initrd.network = {
      enable = true;
      postCommands = ''
        # mkdir -p /mnt/campfs
        # mount -t nfs -o vers=4 10.8.0.140:/mnt/campfs /mnt/campfs
        echo $(echo $(${pkgs.curl}/bin/curl -s $cfg.keyfile-url) | ${pkgs.clevis}/bin/clevis decrypt) > /luks.key
        cat /luks.key
        cryptsetup luksOpen --key-file /luks.key /dev/nvme0n1p2 luks
      '';
      ssh = {
        enable = true;
        port = 22;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
        hostKeys = ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"];
      };
    };
    # TODO: This should probably be parameterized and or not here because it could vary per system
    # use this lspci -v | grep -iA8 'network\|ethernet' to then ask Chad what modules to use here
    boot.initrd.availableKernelModules = ["iwlwifi" "igc" "nfsv4"];
    boot.kernelParams = ["ip=dhcp"];
  };
}
