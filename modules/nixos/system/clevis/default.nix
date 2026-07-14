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

    boot.initrd.network = {
      enable = true;

      # Runs after initrd networking is up.
      # IMPORTANT: do not "exit" PID 1; everything is inside a subshell.
      postCommands = ''
                (
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
                      # Drop key for the normal initrd unlock path (systemd-cryptsetup / cryptsetup tooling)
                      printf '%s' "$key" > "$keyfile"
                      echo "Key dropped at $keyfile (initrd will use it to unlock ${cfg.luksName})"
                      ${pkgs.cryptsetup}/bin/cryptsetup luksOpen --key-file "$keyfile" "${effectiveLuksDevice}" "${cfg.luksName}"
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

                  # Fallback: prompt for passphrase on the correct device.
                  echo "Falling back to passphrase prompt for ${effectiveLuksDevice}..."
                  ${pkgs.cryptsetup}/bin/cryptsetup luksOpen --key-file "${cfg.keyDropPath}/${cfg.luksName}" "${effectiveLuksDevice}" "${cfg.luksName}"
        luksOpen --key-file /luks.key
                ) || true
      '';

      ssh = mkIf cfg.enableInitrdSsh {
        enable = true;
        port = cfg.sshPort;
        shell = "/bin/cryptsetup-askpass";
        authorizedKeys = cfg.sshAuthorizedKeys;
        hostKeys = cfg.sshHostKeys;
      };
    };

    # Ensure referenced binaries exist in initrd
    # nixpkgs 26.05: clevis v22 wraps the real binary as .clevis-wrapped
    # with separate clevis-decrypt* sub-binaries.  The wrapper sets up a
    # full PATH referencing many store paths; we copy the wrapped binary,
    # all decrypt sub-binaries, and strip the absolute store references
    # from the wrapper so the scripts fall back to initrd-local PATH lookups.
    boot.initrd.extraUtilsCommands = ''
      # Clevis: copy the wrapped binary and rename it to clevis
      copy_bin_and_libs ${pkgs.clevis}/bin/.clevis-wrapped
      mv "$out"/bin/{.clevis-wrapped,clevis}

      # Copy all clevis-decrypt* sub-binaries (decrypt, decrypt-tang,
      # decrypt-tpm2, decrypt-sss, decrypt-null)
      for BIN in ${pkgs.clevis}/bin/clevis-decrypt*; do
        copy_bin_and_libs "$BIN"
      done

      # Strip store path references from clevis scripts so they work in the
      # minimal initrd environment with busybox / basic PATH lookups.
      for BIN in "$out"/bin/clevis "$out"/bin/clevis-decrypt*; do
        sed -i "$BIN" \
          -e 's,${pkgs.bash},,g' \
          -e 's,${pkgs.coreutils},,g'
      done

      # curl, cryptsetup, ip — same as before
      copy_bin_and_libs ${pkgs.curl}/bin/curl
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
      copy_bin_and_libs ${pkgs.iproute2}/bin/ip
    '';
  };
}
