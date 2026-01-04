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

    luksDevice =
      mkOpt str "/dev/nvme0n1p2"
      "Block device path for the LUKS partition";

    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko name).";

    luksKeyPath =
      mkOpt str "/luks.key"
      "Path in initrd where the decrypted keyfile will be written.";

    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use when opening the LUKS device. Null means default behavior.";

    networkModules =
      mkOpt (listOf str) []
      "Kernel modules needed for network access during boot.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    # IMPORTANT: avoid self-referential forcing of disko.devices.disk here.
    # Best practice: set initrdUnlock = false in the disko partition definition directly.

    boot.initrd.network = {
      enable = true;

      preLVMCommands = ''
        set -euo pipefail

        echo "Attempting clevis key fetch+decrypt..."

        umask 0077

        # If clevis path works, create a keyfile and open luks with it.
        if enc="$(${pkgs.curl}/bin/curl -fsSL \
              --connect-timeout 5 --max-time 15 \
              "${cfg.keyfile-url}")"
        then
          if key="$(printf '%s' "$enc" | ${pkgs.clevis}/bin/clevis decrypt)"
          then
            printf '%s' "$key" > "${cfg.luksKeyPath}"

            if [ ! -e /dev/mapper/${cfg.luksName} ]; then
              echo "Opening LUKS device ${cfg.luksDevice} as ${cfg.luksName} using clevis key..."
              ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
                --key-file "${cfg.luksKeyPath}" \
                ${optionalString (cfg.luksKeySlot != null) "--key-slot ${toString cfg.luksKeySlot}"} \
                "${cfg.luksDevice}" \
                "${cfg.luksName}"
            else
              echo "LUKS device ${cfg.luksName} already open"
            fi

            rm -f "${cfg.luksKeyPath}"
            echo "Clevis unlock succeeded."
            exit 0
          else
            echo "Clevis decrypt failed."
          fi
        else
          echo "Fetch failed for ${cfg.keyfile-url}"
        fi

        # Fallback: prompt for passphrase (console + initrd ssh askpass)
        echo "Falling back to passphrase prompt..."
        if [ ! -e /dev/mapper/${cfg.luksName} ]; then
          ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
            "${cfg.luksDevice}" \
            "${cfg.luksName}"
        fi
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

    # Don't clobber existing initrd modules / kernel params
    boot.initrd.availableKernelModules = mkAfter cfg.networkModules;
    boot.kernelParams = mkAfter ["ip=dhcp"];

    # Ensure the exact store-path binaries referenced by the script exist in initrd
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.clevis}/bin/clevis
      copy_bin_and_libs ${pkgs.curl}/bin/curl
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
      copy_bin_and_libs ${pkgs.iproute2}/bin/ip
    '';
  };
}
