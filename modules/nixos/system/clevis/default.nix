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

    boot.initrd = {
      availableKernelModules = cfg.availableKernelModules;

      systemd = {
        enable = true;

        # Network configuration for Tang access
        network = {
          enable = true;
          networks."10-initrd" = {
            matchConfig.Type = "ether";
            networkConfig.DHCP = "yes";
          };
        };

        # Clevis unlock service for Tang mode
        services.clevis-luks-unlock = mkIf (cfg.mode == "tang") {
          description = "Unlock LUKS with Clevis/Tang";
          wantedBy = [ "systemd-cryptsetup@${cfg.luks-name}.service" ];
          before = [ "systemd-cryptsetup@${cfg.luks-name}.service" "cryptsetup-pre.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.DefaultDependencies = false;
          script = ''
            echo "Attempting to unlock ${cfg.luks-device} with Clevis/Tang..."
            ${pkgs.clevis}/bin/clevis luks unlock -d ${cfg.luks-device} -n ${cfg.luks-name} && exit 0
            echo "Clevis unlock failed, falling back to password prompt"
            exit 0
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        # HTTP keyfile unlock service for legacy mode
        services.clevis-http-unlock = mkIf (cfg.mode == "http-keyfile") {
          description = "Unlock LUKS with HTTP Keyfile";
          before = [ "systemd-cryptsetup@${cfg.keyfile-luks-name}.service" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          script = ''
            echo "Fetching and decrypting keyfile from ${cfg.keyfile-url}..."
            ${pkgs.curl}/bin/curl -s ${cfg.keyfile-url} | ${pkgs.clevis}/bin/clevis decrypt > /luks.key
            ${pkgs.cryptsetup}/bin/cryptsetup luksOpen --key-file /luks.key ${cfg.keyfile-luks-device} ${cfg.keyfile-luks-name}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      };

      # SSH access in initrd (optional)
      network.ssh = mkIf cfg.ssh-enable {
        enable = true;
        port = cfg.ssh-port;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = cfg.ssh-authorized-keys;
        hostKeys = ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"];
      };
    };

    boot.kernelParams = ["ip=dhcp"];
  };
}
