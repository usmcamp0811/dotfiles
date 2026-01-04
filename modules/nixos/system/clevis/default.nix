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

    mode = mkOption {
      type = enum ["tang" "http-keyfile"];
      default = "tang";
      description = "Clevis unlock mode: 'tang' for Tang server, 'http-keyfile' for HTTP keyfile server";
    };

    # Tang mode options
    luks-device = mkOpt str "/dev/disk/by-partlabel/disk-main-luks" "LUKS device to unlock with Clevis";
    luks-name = mkOpt str "crypted" "Name for the unlocked LUKS device";

    # HTTP keyfile mode options (legacy)
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
    keyfile-url = mkOpt str "http://key-server:8080/zfs-keyfile" "The URL for the Clevis encrypted Keyfile";
    keyfile-luks-device = mkOpt str "/dev/nvme0n1p2" "LUKS device for HTTP keyfile mode";
    keyfile-luks-name = mkOpt str "luks" "LUKS name for HTTP keyfile mode";

    # Network options
    availableKernelModules = mkOpt (listOf str) ["igc"] "Network kernel modules for initrd";
    ssh-enable = mkBoolOpt false "Enable SSH in initrd";
    ssh-port = mkOpt int 22 "SSH port in initrd";
    ssh-authorized-keys = mkOpt (listOf str) [] "SSH authorized keys for initrd";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis jose];

    boot.initrd.network = {
      enable = true;

      postCommands =
        if cfg.mode == "tang" then ''
          # Tang mode: Use clevis to unlock LUKS directly
          echo "Attempting to unlock ${cfg.luks-device} with Clevis/Tang..."
          ${pkgs.clevis}/bin/clevis luks unlock -d ${cfg.luks-device} -n ${cfg.luks-name} || echo "Clevis unlock failed, falling back to password prompt"
        ''
        else ''
          # HTTP keyfile mode (legacy)
          echo "Fetching and decrypting keyfile from ${cfg.keyfile-url}..."
          echo $(echo $(${pkgs.curl}/bin/curl -s ${cfg.keyfile-url}) | ${pkgs.clevis}/bin/clevis decrypt) > /luks.key
          cat /luks.key
          ${pkgs.cryptsetup}/bin/cryptsetup luksOpen --key-file /luks.key ${cfg.keyfile-luks-device} ${cfg.keyfile-luks-name}
        '';

      ssh = mkIf cfg.ssh-enable {
        enable = true;
        port = cfg.ssh-port;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = cfg.ssh-authorized-keys;
        hostKeys = ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"];
      };
    };

    boot.initrd.availableKernelModules = cfg.availableKernelModules;
    boot.kernelParams = ["ip=dhcp"];
  };
}
