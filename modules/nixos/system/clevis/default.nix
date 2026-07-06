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

  # If luksDevice is null, try to infer it from disko when there's exactly one luks partition.
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
    luksParts = builtins.filter (x: (x.part.content.type or "") == "luks") parts;
  in
    if builtins.length luksParts == 1
    then let
      diskDevice = (builtins.head luksParts).disk.device or null;
    in
      # Your layout: ESP is part1, LUKS is part2
      if diskDevice != null && lib.hasPrefix "/dev/disk/by-id/" diskDevice
      then "${diskDevice}-part2"
      else null
    else null;

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

    # Allow null so we can infer from disko when possible.
    luksDevice =
      mkOpt (nullOr str) null
      "Block device path for the LUKS partition (e.g. /dev/disk/by-id/...-part2). If null, tries to infer from disko when possible.";

    luksName =
      mkOpt str "crypted"
      "Name for the opened LUKS mapping (must match disko luks name).";

    # Where to drop the key for initrd/systemd-cryptsetup
    keyDropPath =
      mkOpt str "/run/cryptsetup-keys.d"
      "Directory in initrd to drop keyfiles for cryptsetup (key will be <keyDropPath>/<luksName>.key).";

    # Optional: only used in the *fallback* manual luksOpen path (passphrase prompt),
    # but kept because it can help if you pin a slot.
    luksKeySlot =
      mkOpt (nullOr int) null
      "Optional keyslot to use (applies only to keyfile-based luksOpen, not the passphrase prompt).";

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
        message = ''
          fmf.system.clevis: luksDevice is null and could not be inferred from disko.
          Set fmf.system.clevis.luksDevice (for edson it should be /dev/disk/by-id/ata-FPT310M4SSD256G_221209A00529-part2).
        '';
      }
    ];

    environment.systemPackages = with pkgs; [clevis cryptsetup curl];

    boot.kernelParams = mkAfter ["ip=dhcp"];
    boot.initrd.availableKernelModules = mkAfter cfg.networkModules;

    # Enable network in initrd (used for systemd-networkd in systemd stage 1)
    boot.initrd.network.enable = true;

    # SSH in initrd for remote unlock
    boot.initrd.network.ssh = mkIf cfg.enableInitrdSsh {
      enable = true;
      port = cfg.sshPort;
      # Shell removed: cryptsetup-askpass is not available in systemd stage 1.
      # The default shell allows the user to run cryptsetup manually and
      # then `systemctl default` to continue boot.
      authorizedKeys = cfg.sshAuthorizedKeys;
      hostKeys = cfg.sshHostKeys;
    };

    # Systemd service to fetch clevis key before cryptsetup tries to unlock.
    # This only drops the key into /run/cryptsetup-keys.d/; it does NOT
    # run cryptsetup luksOpen directly.  systemd-cryptsetup will pick up
    # the key automatically.  If the fetch fails, no key is dropped and
    # systemd-cryptsetup will prompt for a password on the console.
    boot.initrd.systemd.services.fetch-clevis-key = {
      wantedBy = ["initrd.target"];
      after = ["network-online.target"];
      before = ["systemd-cryptsetup@${cfg.luksName}.service"];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        # If already open, nothing to do.
        if [ -e "/dev/mapper/${cfg.luksName}" ]; then
          echo "LUKS device ${cfg.luksName} already open; skipping."
          exit 0
        fi

        keydir="${cfg.keyDropPath}"
        keyfile="$keydir/${cfg.luksName}.key"
        mkdir -p "$keydir"
        umask 0077

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
            echo "Key dropped at $keyfile (systemd-cryptsetup will use it to unlock ${cfg.luksName})"
            exit 0
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

        # No key was obtained.  systemd-cryptsetup will prompt on console
        # for a password.  If SSH is enabled, the user can also SSH in,
        # manually unlock, then run `systemctl default`.
      '';
    };

    # Ensure referenced binaries exist in initrd via store paths (systemd stage 1)
    boot.initrd.systemd.storePaths = [
      "${pkgs.clevis}/bin/clevis"
      "${pkgs.curl}/bin/curl"
      "${pkgs.cryptsetup}/bin/cryptsetup"
      "${pkgs.iproute2}/bin/ip"
    ];
  };
}
