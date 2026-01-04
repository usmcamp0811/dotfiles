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
      type = enum ["http-keyfile" "tang"];
      default = "http-keyfile";
      description = "Clevis mode: 'http-keyfile' for HTTP keyfile server, 'tang' for Tang server";
    };

    # Common options
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";

    # HTTP keyfile mode options
    keyfile-url = mkOpt str "http://key-server:8080/zfs-keyfile" "The URL for the Clevis encrypted Keyfile";
    luks-device = mkOpt str "/dev/nvme0n1p2" "LUKS device to unlock";
    luks-name = mkOpt str "luks" "Name for the unlocked LUKS device";

    # Tang mode options
    tang-luks-device = mkOpt str "/dev/disk/by-partlabel/disk-main-luks" "LUKS device for Tang mode";
    tang-luks-name = mkOpt str "crypted" "Name for Tang unlocked device";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis];

    boot.initrd = mkMerge [
      # Common configuration
      {
        availableKernelModules = ["iwlwifi" "igc" "nfsv4"];
      }

      # For non-systemd initrd (legacy)
      (mkIf (!config.boot.initrd.systemd.enable) {
        network = {
          enable = true;
          postCommands =
            if cfg.mode == "tang" then ''
              # Tang mode: use clevis to unlock directly
              ${pkgs.clevis}/bin/clevis luks unlock -d ${cfg.tang-luks-device} -n ${cfg.tang-luks-name} || echo "Clevis/Tang unlock failed, falling back to password"
            ''
            else ''
              # HTTP keyfile mode (original behavior)
              echo $(echo $(${pkgs.curl}/bin/curl -s ${cfg.keyfile-url}) | ${pkgs.clevis}/bin/clevis decrypt) > /luks.key
              cat /luks.key
              cryptsetup luksOpen --key-file /luks.key ${cfg.luks-device} ${cfg.luks-name}
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
      })

      # For systemd initrd
      (mkIf config.boot.initrd.systemd.enable {
        systemd.network = {
          enable = true;
          networks."10-initrd" = {
            matchConfig.Type = "ether";
            networkConfig.DHCP = "yes";
          };
        };

        systemd.services.clevis-unlock = {
          description = "Unlock LUKS with Clevis";
          before = [ "cryptsetup-pre.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.DefaultDependencies = false;
          script =
            if cfg.mode == "tang" then ''
              ${pkgs.clevis}/bin/clevis luks unlock -d ${cfg.tang-luks-device} -n ${cfg.tang-luks-name} || echo "Clevis/Tang unlock failed"
            ''
            else ''
              ${pkgs.curl}/bin/curl -s ${cfg.keyfile-url} | ${pkgs.clevis}/bin/clevis decrypt > /luks.key
              ${pkgs.cryptsetup}/bin/cryptsetup luksOpen --key-file /luks.key ${cfg.luks-device} ${cfg.luks-name}
            '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      })
    ];

    boot.kernelParams = ["ip=dhcp"];
  };
}
