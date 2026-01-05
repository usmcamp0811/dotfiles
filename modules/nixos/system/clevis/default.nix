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

  defaultInitrdAuthorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler";

  # If user leaves luksDevice at default, try to infer it from disko if there's exactly one luks partition.
  inferredLuksDevice = let
    disks = config.disko.devices.disk or {};
    parts = lib.concatLists (
      map (
        disk:
          map (p: {
            disk = disk;
            part = p;
          })
          (attrValues (disk.content.partitions or {}))
      ) (attrValues disks)
    );
    luksParts =
      builtins.filter (x: (x.part.content.type or "") == "luks") parts;
    pick =
      if builtins.length luksParts == 1
      then let
        diskDevice = (builtins.head luksParts).disk.device or null;
        # disko in your case: ESP is part1, luks is part2
        # We can only safely infer "-part2" when diskDevice is a /dev/disk/by-id/* path.
      in
        if diskDevice != null && lib.hasPrefix "/dev/disk/by-id/" diskDevice
        then "${diskDevice}-part2"
        else null
      else null;
  in
    pick;

  effectiveLuksDevice =
    if cfg.luksDevice != null
    then cfg.luksDevice
    else inferredLuksDevice;
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Enable Clevis-based initrd key drop-in for LUKS unlock.";

    keyfile-url =
      mkOpt str "http://10.8.0.1/zfs-keyfile"
      "URL to fetch the Clevis-encrypted keyfile from (reachable in initrd).";

    # Allow null so we can infer from disko when possible
    luksDevice =
      mkOpt (nullOr str) null
      "Block device path for the LUKS partition (e.g. /dev/disk/by-id/...-part2). If null, tries to infer from disko when possible.";

    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko luks name).";

    # Where to drop the key for initrd/systemd-cryptsetup
    keyDropPath =
      mkOpt str "/run/cryptsetup-keys.d"
      "Directory in initrd to drop keyfiles for cryptsetup.";

    enableInitrdSsh =
      mkBoolOpt true "Enable SSH in initrd for remote unlocking.";
    sshPort =
      mkOpt port 22 "SSH port for initrd.";
    sshAuthorizedKeys =
      mkOpt (listOf str) [defaultInitrdAuthorizedKey]
      "Authorized keys for initrd SSH (must be non-empty if enabled).";
    sshHostKeys =
      mkOpt (listOf path) ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"]
      "Host keys for initrd SSH.";

    networkModules =
      mkOpt (listOf str) []
      "Kernel modules needed for network access during initrd.";

    curlConnectTimeoutSeconds =
      mkOpt int 5 "curl connect timeout (seconds) in initrd.";
    curlMaxTimeSeconds =
      mkOpt int 15 "curl max total time (seconds) in initrd.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = effectiveLuksDevice != null;
        message = "fmf.system.clevis: luksDevice is null and could not be inferred from disko. Set fmf.system.clevis.luksDevice (for edson it should be /dev/disk/by-id/ata-FPT310M4SSD256G_221209A00529-part2).";
      }
    ];

    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    boot.kernelParams = mkAfter ["ip=dhcp"];
    boot.initrd.availableKernelModules = mkAfter cfg.networkModules;

    boot.initrd.network = {
      enable = true;

      # postCommands runs after initrd networking is up.
      # We DO NOT luksOpen here; we just drop a keyfile for the normal unlock path.
      postCommands = ''
        set -euo pipefail

        # If already open, nothing to do.
        if [ -e "/dev/mapper/${cfg.luksName}" ]; then
          echo "LUKS device ${cfg.luksName} already open; skipping."
          exit 0
        fi

        mkdir -p "${cfg.keyDropPath}"
        umask 0077

        keyfile="${cfg.keyDropPath}/${cfg.luksName}.key"

        echo "Fetching encrypted keyfile from ${cfg.keyfile-url}..."
        if enc="$(${pkgs.curl}/bin/curl -fsSL \
              --connect-timeout ${toString cfg.curlConnectTimeoutSeconds} \
              --max-time ${toString cfg.curlMaxTimeSeconds} \
              "${cfg.keyfile-url}")"
        then
          echo "Decrypting keyfile with clevis..."
          if key="$(printf '%s' "$enc" | ${pkgs.clevis}/bin/clevis decrypt)"
          then
            printf '%s' "$key" > "$keyfile"
            echo "Key dropped at $keyfile"
            exit 0
          fi
        fi

        echo "Clevis key drop failed; falling back to passphrase prompt for ${effectiveLuksDevice}"
        # This opens the correct device and creates /dev/mapper/${cfg.luksName}; then normal boot should proceed.
        ${pkgs.cryptsetup}/bin/cryptsetup luksOpen "${effectiveLuksDevice}" "${cfg.luksName}"
      '';

      ssh = mkIf cfg.enableInitrdSsh {
        enable = true;
        port = cfg.sshPort;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = cfg.sshAuthorizedKeys;
        hostKeys = cfg.sshHostKeys;
      };
    };

    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.clevis}/bin/clevis
      copy_bin_and_libs ${pkgs.curl}/bin/curl
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
      copy_bin_and_libs ${pkgs.iproute2}/bin/ip
    '';
  };
}
