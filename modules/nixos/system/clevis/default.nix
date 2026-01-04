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

    keyfile-url =
      mkOpt str "http://10.8.0.1/zfs-keyfile"
      "The URL for the Clevis encrypted Keyfile";

    # What /dev node to open (LUKS container partition)
    luksDevice =
      mkOpt str "/dev/nvme0n1p2"
      "Block device path for the LUKS partition";

    # The mapper name created by cryptsetup (appears under /dev/mapper/<name>)
    # MUST match the disko name to avoid conflicts
    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko.devices.disk.*.content.partitions.*.content.name)";

    # Where to write the decrypted key inside initrd
    luksKeyPath =
      mkOpt str "/luks.key"
      "Path in initrd where the decrypted keyfile will be written.";

    # Optional: if you want to pin a specific key slot (usually leave null)
    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use when opening the LUKS device. Null means default behavior.";

    # Network kernel modules needed for your hardware
    networkModules =
      mkOpt (listOf str) []
      "Kernel modules needed for network access during boot. Use lspci -v | grep -iA8 'network|ethernet' to find yours.";
  };

  config = mkIf cfg.enable {
    # Disable disko's automatic LUKS unlock since we're using clevis
    disko.devices.disk = lib.mkForce (
      lib.mapAttrs (
        name: disk:
          disk
          // {
            content =
              disk.content
              // {
                partitions =
                  lib.mapAttrs (
                    pname: part:
                      if part.content.type or "" == "luks"
                      then
                        part
                        // {
                          content =
                            part.content
                            // {
                              initrdUnlock = false; # Let clevis handle it
                            };
                        }
                      else part
                  )
                  disk.content.partitions;
              };
          }
      )
      config.disko.devices.disk
    );

    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    boot.initrd.network = {
      enable = true;

      # Use preLVMCommands instead of postCommands
      # This runs BEFORE disko tries to mount filesystems
      preLVMCommands = ''
        set -euo pipefail

        echo "Fetching encrypted keyfile from ${cfg.keyfile-url}..."

        # Fetch encrypted keyfile and decrypt with clevis
        enc="$(${pkgs.curl}/bin/curl -fsSL "${cfg.keyfile-url}" || {
          echo "Failed to fetch keyfile from ${cfg.keyfile-url}"
          echo "Network interfaces:"
          ip addr
          echo "Routes:"
          ip route
          exit 1
        })"

        key="$(echo "$enc" | ${pkgs.clevis}/bin/clevis decrypt || {
          echo "Failed to decrypt keyfile with clevis"
          exit 1
        })"

        # Write key to initrd path (avoid leaking to stdout)
        umask 0077
        printf '%s' "$key" > "${cfg.luksKeyPath}"

        echo "Keyfile decrypted successfully"

        # Open LUKS - check if already open first
        if [ ! -e /dev/mapper/${cfg.luksName} ]; then
          echo "Opening LUKS device ${cfg.luksDevice} as ${cfg.luksName}..."
          ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
            --key-file "${cfg.luksKeyPath}" \
            ${optionalString (cfg.luksKeySlot != null) "--key-slot ${toString cfg.luksKeySlot}"} \
            "${cfg.luksDevice}" \
            "${cfg.luksName}" || {
              echo "Failed to open LUKS device"
              exit 1
            }
          echo "LUKS device opened successfully"
        else
          echo "LUKS device ${cfg.luksName} already open"
        fi

        # Clean up keyfile
        rm -f "${cfg.luksKeyPath}"
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

    boot.initrd.availableKernelModules = cfg.networkModules;
    boot.kernelParams = ["ip=dhcp"];

    # Add clevis tools to initrd
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.clevis}/bin/clevis
      copy_bin_and_libs ${pkgs.curl}/bin/curl
    '';
  };
}
