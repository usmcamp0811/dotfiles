# fmf/modules/system/clevis.nix
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
      "Block device path for the LUKS partition (e.g. /dev/nvme0n1p2 or /dev/disk/by-id/...-part2).";

    # The mapper name created by cryptsetup (appears under /dev/mapper/<name>)
    luksName =
      mkOpt str "luks"
      "Name for the opened LUKS mapping (cryptsetup luksOpen ... <name>).";

    # Where to write the decrypted key inside initrd
    luksKeyPath =
      mkOpt str "/luks.key"
      "Path in initrd where the decrypted keyfile will be written.";

    # Optional: if you want to pin a specific key slot (usually leave null)
    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use when opening the LUKS device. Null means default behavior.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    boot.initrd.network = {
      enable = true;

      postCommands = ''
        set -euo pipefail

        # Fetch encrypted keyfile and decrypt with clevis
        enc="$(${pkgs.curl}/bin/curl -fsSL "${cfg.keyfile-url}")"
        key="$(echo "$enc" | ${pkgs.clevis}/bin/clevis decrypt)"

        # Write key to initrd path (avoid leaking to stdout)
        umask 0077
        printf '%s' "$key" > "${cfg.luksKeyPath}"

        # Open LUKS
        ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
          --key-file "${cfg.luksKeyPath}" \
          ${optionalString (cfg.luksKeySlot != null) "--key-slot ${toString cfg.luksKeySlot}"} \
          "${cfg.luksDevice}" \
          "${cfg.luksName}"
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
