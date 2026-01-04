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

  # Walk disko config (read-only) to see whether any LUKS partition still has initrdUnlock enabled.
  # We DO NOT try to rewrite disko here (doing so safely requires editing the disko definition itself).
  diskoHasInitrdUnlockEnabled = let
    disks = config.disko.devices.disk or {};
    partsOf = disk: (disk.content.partitions or {});
    partIsLuks = part: (part.content.type or "") == "luks";
    initrdUnlockEnabled = part: let
      v = part.content.initrdUnlock or null;
    in
      v == true || v == null; # null usually means "default" (which is effectively enabled)
    diskHas = disk:
      any (part: partIsLuks part && initrdUnlockEnabled part) (attrValues (partsOf disk));
  in
    any diskHas (attrValues disks);
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis-based initrd unlock.";

    keyfile-url =
      mkOpt str "http://10.8.0.1/zfs-keyfile"
      "URL to fetch the Clevis-encrypted keyfile from (reachable in initrd).";

    # What /dev node to open (LUKS container partition)
    luksDevice =
      mkOpt str "/dev/nvme0n1p2"
      "Block device path for the LUKS partition.";

    # The mapper name created by cryptsetup (appears under /dev/mapper/<name>)
    # MUST match the disko luks name to avoid conflicts.
    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko's luks content name).";

    # Where to write the decrypted key inside initrd (temporary file)
    luksKeyPath =
      mkOpt str "/luks.key"
      "Path in initrd where the decrypted keyfile will be written temporarily.";

    # Optional: if you want to pin a specific key slot (usually leave null)
    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use when opening the LUKS device. Null means default behavior.";

    # Network kernel modules needed for your hardware (added to initrd modules list)
    networkModules =
      mkOpt (listOf str) []
      "Kernel modules needed for network access during initrd.";

    # Initrd SSH settings (so you can recover if auto-unlock fails)
    enableInitrdSsh =
      mkBoolOpt true "Enable SSH in initrd for remote unlocking.";
    sshPort =
      mkOpt port 22 "SSH port for initrd.";
    sshAuthorizedKeys =
      mkOpt (listOf str) []
      "Authorized keys for initrd SSH.";
    sshHostKeys =
      mkOpt (listOf path) ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"]
      "Host keys to use for initrd SSH (must exist in the real root).";

    # Curl timeouts (avoid hanging forever in initrd)
    curlConnectTimeoutSeconds =
      mkOpt int 5 "curl connect timeout (seconds) in initrd.";
    curlMaxTimeSeconds =
      mkOpt int 15 "curl max total time (seconds) in initrd.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    # Strong hint if disko is still trying to unlock in initrd too (common source of conflicts).
    warnings = optional diskoHasInitrdUnlockEnabled ''
      fmf.system.clevis: disko has at least one LUKS partition with initrdUnlock not set to false.
      This can conflict with clevis unlocking. Prefer setting `content.initrdUnlock = false;` in the
      disko LUKS partition definition directly.
    '';

    # Ensure initrd networking is actually configured
    boot.kernelParams = mkAfter ["ip=dhcp"];
    boot.initrd.availableKernelModules = mkAfter cfg.networkModules;

    boot.initrd.network = {
      enable = true;

      # Runs after initrd networking is configured
      postCommands = ''
        set -euo pipefail

        # If already open, don't do anything.
        if [ -e "/dev/mapper/${cfg.luksName}" ]; then
          echo "LUKS device ${cfg.luksName} already open; skipping clevis unlock."
          exit 0
        fi

        echo "Attempting clevis key fetch+decrypt..."

        umask 0077

        # Fetch encrypted keyfile
        if enc="$(${pkgs.curl}/bin/curl -fsSL \
              --connect-timeout ${toString cfg.curlConnectTimeoutSeconds} \
              --max-time ${toString cfg.curlMaxTimeSeconds} \
              "${cfg.keyfile-url}")"
        then
          # Decrypt with clevis
          if key="$(printf '%s' "$enc" | ${pkgs.clevis}/bin/clevis decrypt)"
          then
            # Write key to a temp file (avoid printing secrets)
            printf '%s' "$key" > "${cfg.luksKeyPath}"

            echo "Opening LUKS device ${cfg.luksDevice} as ${cfg.luksName} using clevis key..."
            ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
              --key-file "${cfg.luksKeyPath}" \
              ${optionalString (cfg.luksKeySlot != null) "--key-slot ${toString cfg.luksKeySlot}"} \
              "${cfg.luksDevice}" \
              "${cfg.luksName}" || true

            rm -f "${cfg.luksKeyPath}"

            if [ -e "/dev/mapper/${cfg.luksName}" ]; then
              echo "Clevis unlock succeeded."
              exit 0
            else
              echo "Clevis path ran, but LUKS is still not open."
            fi
          else
            echo "Clevis decrypt failed."
          fi
        else
          echo "Fetch failed for ${cfg.keyfile-url}"
          echo "Interfaces:"
          ${pkgs.iproute2}/bin/ip addr || true
          echo "Routes:"
          ${pkgs.iproute2}/bin/ip route || true
        fi

        # Fallback: prompt for passphrase (console + initrd ssh askpass)
        echo "Falling back to passphrase prompt..."
        ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
          "${cfg.luksDevice}" \
          "${cfg.luksName}"
      '';

      ssh = mkIf cfg.enableInitrdSsh {
        enable = true;
        port = cfg.sshPort;

        # This is the standard NixOS initrd ssh "unlock" shell
        shell = "/bin/cryptsetup-askpass";

        authorizedKeys = cfg.sshAuthorizedKeys;
        hostKeys = cfg.sshHostKeys;
      };
    };

    # Add required tools into initrd (because the script references store paths)
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.clevis}/bin/clevis
      copy_bin_and_libs ${pkgs.curl}/bin/curl
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
      copy_bin_and_libs ${pkgs.iproute2}/bin/ip
    '';
  };
}
