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

  diskoHasInitrdUnlockEnabled = let
    disks = config.disko.devices.disk or {};
    partsOf = disk: (disk.content.partitions or {});
    partIsLuks = part: (part.content.type or "") == "luks";
    initrdUnlockEnabled = part: let
      v = part.content.initrdUnlock or null;
    in
      v == true || v == null;
    diskHas = disk:
      any (part: partIsLuks part && initrdUnlockEnabled part) (attrValues (partsOf disk));
  in
    any diskHas (attrValues disks);

  defaultInitrdAuthorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler";
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis-based initrd unlock.";

    keyfile-url =
      mkOpt str "http://10.8.0.1/zfs-keyfile"
      "URL to fetch the Clevis-encrypted keyfile from (reachable in initrd).";

    luksDevice =
      mkOpt str "/dev/nvme0n1p2"
      "Block device path for the LUKS partition.";

    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko's luks content name).";

    luksKeyPath =
      mkOpt str "/luks.key"
      "Path in initrd where the decrypted keyfile will be written temporarily.";

    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use when opening the LUKS device. Null means default behavior.";

    networkModules =
      mkOpt (listOf str) []
      "Kernel modules needed for network access during initrd.";

    enableInitrdSsh =
      mkBoolOpt true "Enable SSH in initrd for remote unlocking.";
    sshPort =
      mkOpt port 22 "SSH port for initrd.";
    sshAuthorizedKeys =
      mkOpt (listOf str) [defaultInitrdAuthorizedKey]
      "Authorized keys for initrd SSH (must be non-empty if initrd SSH is enabled).";
    sshHostKeys =
      mkOpt (listOf path) ["/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key"]
      "Host keys to use for initrd SSH (must exist in the real root).";

    curlConnectTimeoutSeconds =
      mkOpt int 5 "curl connect timeout (seconds) in initrd.";
    curlMaxTimeSeconds =
      mkOpt int 15 "curl max total time (seconds) in initrd.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    warnings = optional diskoHasInitrdUnlockEnabled ''
      fmf.system.clevis: disko has at least one LUKS partition with initrdUnlock not set to false.
      This can conflict with clevis unlocking. Prefer setting `content.initrdUnlock = false;` in the
      disko LUKS partition definition directly.
    '';

    boot.kernelParams = mkAfter ["ip=dhcp"];
    boot.initrd.availableKernelModules = mkAfter cfg.networkModules;

    boot.initrd.network = {
      enable = true;

      postCommands = ''
        set -euo pipefail

        if [ -e "/dev/mapper/${cfg.luksName}" ]; then
          echo "LUKS device ${cfg.luksName} already open; skipping clevis unlock."
          exit 0
        fi

        echo "Attempting clevis key fetch+decrypt..."
        umask 0077

        if enc="$(${pkgs.curl}/bin/curl -fsSL \
              --connect-timeout ${toString cfg.curlConnectTimeoutSeconds} \
              --max-time ${toString cfg.curlMaxTimeSeconds} \
              "${cfg.keyfile-url}")"
        then
          if key="$(printf '%s' "$enc" | ${pkgs.clevis}/bin/clevis decrypt)"
          then
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

        echo "Falling back to passphrase prompt..."
        ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
          "${cfg.luksDevice}" \
          "${cfg.luksName}"
      '';

      ssh = mkIf cfg.enableInitrdSsh {
        enable = true;
        port = cfg.sshPort;
        shell = "/bin/cryptsetup-askpass";

        # must be non-empty when enabled
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
