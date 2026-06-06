{ options, config, pkgs, lib, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.system.zfs;
  zfsUnlockScript = ''
    set +e

    echo "[ZFS Unlock] Importing available pools without mounting..."
    zpool import -a -N || true

    LOCKED_ROOTS=$(for dataset in $(zfs get -H -o name,value keystatus -t filesystem,volume | awk '$2 == "unavailable" { print $1 }'); do
      zfs get -H -o value encryptionroot "$dataset"
    done | grep -v '^-$' | sort -u)

    if [ -z "$LOCKED_ROOTS" ]; then
      echo "[ZFS Unlock] No locked encryption roots found"
      exit 0
    fi

    KEYFILE_DIR=$(mktemp -d -p /run zfs-unlock.XXXXXX)
    chmod 700 "$KEYFILE_DIR"
    KEYFILE_PATH="$KEYFILE_DIR/passphrase"
    trap "shred -u '$KEYFILE_PATH' 2>/dev/null || rm -f '$KEYFILE_PATH'; rmdir '$KEYFILE_DIR' 2>/dev/null" EXIT

    echo "[ZFS Unlock] Fetching encrypted keyfile from ${cfg.keyfile-url}..."
    RETRY_COUNT=0
    MAX_RETRIES=3
    DECRYPT_SUCCESS=0

    while [ $DECRYPT_SUCCESS -eq 0 ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 ${cfg.keyfile-url} \
        | ${pkgs.clevis}/bin/clevis decrypt > "$KEYFILE_PATH" 2>/dev/null; then
        DECRYPT_SUCCESS=1
      else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
          echo "[ZFS Unlock] Fetch/decrypt failed (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 3 seconds..."
          sleep 3
        fi
      fi
    done

    if [ $DECRYPT_SUCCESS -eq 0 ] || [ ! -s "$KEYFILE_PATH" ]; then
      echo "[ZFS Unlock] ERROR: Failed to fetch/decrypt a usable keyfile"
      exit 1
    fi

    UNLOCK_SUCCESS=0
    UNLOCK_FAILED=0

    for dataset in $LOCKED_ROOTS; do
      echo "[ZFS Unlock] Loading key for encryption root: $dataset"
      if zfs load-key -L "file://$KEYFILE_PATH" "$dataset"; then
        UNLOCK_SUCCESS=$((UNLOCK_SUCCESS + 1))
      else
        UNLOCK_FAILED=$((UNLOCK_FAILED + 1))
        echo "[ZFS Unlock] WARNING: Failed to load key for $dataset"
      fi
    done

    echo "[ZFS Unlock] Summary: $UNLOCK_SUCCESS unlocked, $UNLOCK_FAILED failed"

    if [ $UNLOCK_SUCCESS -gt 0 ]; then
      exit 0
    fi

    exit 1
  '';

  # Compute the ZFS pools that are imported in the initrd (i.e. the pools that
  # contain filesystems needed for boot, such as the root pool). This mirrors
  # the logic in nixpkgs' tasks/filesystems/zfs.nix so we can hook the exact
  # generated `zfs-import-<pool>` initrd services.
  #
  # A filesystem is needed for boot if it is explicitly marked neededForBoot,
  # or its mountpoint is one of the boot-critical paths (matching the
  # `utils.fsNeededForBoot` predicate in nixpkgs without depending on `utils`).
  neededForBootMounts = [ "/" "/nix" "/nix/store" "/var" "/var/log" "/var/lib" "/var/lib/nixos" "/etc" "/usr" ];
  fsNeededForBoot = fs: fs.neededForBoot or false || lib.elem fs.mountPoint neededForBootMounts;
  datasetToPool = x: lib.elemAt (lib.splitString "/" x) 0;
  fsToPool = fs: datasetToPool fs.device;
  zfsFilesystems = lib.filter (x: x.fsType == "zfs") config.system.build.fileSystems;
  initrdRootPools =
    lib.unique (map fsToPool (lib.filter fsNeededForBoot zfsFilesystems));
in {
  options.fmf.system.zfs = with types; {
    enable = mkBoolOpt false "Whether or not to configure zfs.";
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
    keyfile-url = mkOpt str "http://10.8.0.1/zfs-keyfile"
      "The URL for the Clevis encrypted Keyfile";
    public_keys = mkOpt (lib.types.listOf lib.types.str) [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler"
    ]
      "List of public ssh keys to access the Phase 1 Boot for remote unlocking of ZFS";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      clevis
      (writeScriptBin "zfs-unlock-manual" ''
        #!${pkgs.bash}/bin/bash
        set -e

        echo "=== Manual ZFS Unlock Script ==="
        echo ""

        echo "Step 1: Checking for pools to import..."
        if ${pkgs.zfs}/bin/zpool import 2>&1 | ${pkgs.gnugrep}/bin/grep -q "pool:"; then
          echo "Found pools that need importing:"
          ${pkgs.zfs}/bin/zpool import
          echo ""
          read -p "Import all pools? (y/n) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${pkgs.zfs}/bin/zpool import -a -N
            echo "Pools imported"
          fi
        else
          echo "All pools already imported"
        fi

        echo ""
        echo "Step 2: Checking for locked datasets..."
        LOCKED=$(${pkgs.zfs}/bin/zfs get -H -o name,value keystatus -t filesystem,volume | ${pkgs.gawk}/bin/awk '$2 == "unavailable" { print $1 }' || true)

        if [ -z "$LOCKED" ]; then
          echo "✓ No locked datasets found! All datasets are unlocked."
          echo ""
          echo "Step 3: Mounting datasets..."
          ${pkgs.zfs}/bin/zfs mount -a
          echo "✓ Done!"
          exit 0
        fi

        echo "Found locked datasets:"
        echo "$LOCKED"
        echo ""

        read -p "Attempt automatic unlock via Tang? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          KEYFILE=$(${pkgs.coreutils}/bin/mktemp)
          trap "${pkgs.coreutils}/bin/shred -u $KEYFILE 2>/dev/null || ${pkgs.coreutils}/bin/rm -f $KEYFILE" EXIT

          echo "Step 3: Fetching and decrypting keyfile from Tang server..."
          if ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 ${cfg.keyfile-url} | ${pkgs.clevis}/bin/clevis decrypt > "$KEYFILE" 2>&1; then
            echo "✓ Successfully decrypted keyfile"
            echo ""
            echo "Step 4: Loading keys for locked datasets..."

            SUCCESS=0
            FAILED=0

            for dataset in $LOCKED; do
              echo "  Unlocking $dataset..."
              if ${pkgs.zfs}/bin/zfs load-key -L "file://$KEYFILE" "$dataset" 2>&1; then
                echo "  ✓ Successfully unlocked $dataset"
                SUCCESS=$((SUCCESS + 1))
              else
                echo "  ✗ Failed to unlock $dataset"
                FAILED=$((FAILED + 1))
              fi
            done

            echo ""
            echo "Summary: $SUCCESS unlocked, $FAILED failed"

            if [ $SUCCESS -gt 0 ]; then
              echo ""
              echo "Step 5: Mounting datasets..."
              ${pkgs.zfs}/bin/zfs mount -a
              echo "✓ Done!"
            fi
          else
            echo "✗ Failed to fetch/decrypt keyfile from Tang server"
            echo ""
            echo "Manual unlock command: sudo zfs load-key <dataset>"
            exit 1
          fi
        else
          echo ""
          echo "Manual unlock command: sudo zfs load-key <dataset>"
        fi
      '')
    ];

    boot.supportedFilesystems = [ "zfs" ];
    # The generated initrd `zfs-import-<pool>` units prompt via
    # `systemd-ask-password` when this is true. That races/conflicts with the
    # Tang/Clevis stage-1 unlock path and still produces a passphrase prompt
    # after `zfs-initrd-network-unlock` has run. Keep the prompt path disabled
    # here and rely on our initrd SSH + manual unlock fallback instead.
    boot.zfs.requestEncryptionCredentials = false;
    services.zfs.autoScrub.enable = true;
    services.nfs.server.enable = true;

    boot.kernelPackages = pkgs.linuxPackages_6_6;

    networking.hostId = cfg.hostId;

    boot.initrd.network.enable = true;
    boot.initrd.systemd = {
      enable = true;

      # As of NixOS 26.05, stage-1 initrd uses systemd by default. NixOS
      # generates a `zfs-import-<pool>.service` for each pool needed at boot,
      # and when `boot.zfs.requestEncryptionCredentials` is true that service
      # calls `systemd-ask-password` directly to prompt for the key.
      #
      # Our network-based Tang/Clevis unlock (`zfs-initrd-network-unlock`) ran
      # as an *unordered* peer of those import services, so the password prompt
      # would win the race and ask for the key even though we could fetch it
      # from the key server. Order the generated import services AFTER our
      # unlock service so the key is already loaded (keystatus=available) by
      # the time the import service checks -- it then skips the prompt.
      #
      # This is ordering-only (no `requires`), so if the network unlock fails
      # (key server unreachable, off-network, etc.) the import service still
      # runs and falls back to prompting at the console / via SSH.
      services = (lib.genAttrs
        (map (pool: "zfs-import-${pool}") initrdRootPools)
        (_: {
          after = [ "zfs-initrd-network-unlock.service" ];
          wants = [ "zfs-initrd-network-unlock.service" ];
        })) // {
        zfs-initrd-network-unlock = {
        description = "Unlock ZFS in initrd via Tang/Clevis";
        wantedBy = [ "initrd.target" ];
        after = [ "initrd-network.target" "systemd-udev-settle.service" ];
        wants = [ "initrd-network.target" ];
        before = [ "sysroot.mount" ]
          ++ map (pool: "zfs-import-${pool}.service") initrdRootPools;
        path = with pkgs; [ curl clevis gawk zfs coreutils gnugrep ];
        serviceConfig.Type = "oneshot";
        script = ''
          sleep 5
          ${zfsUnlockScript}
      '';
        };
      };
    };

    boot.initrd.network.ssh = {
      enable = true;
      port = 22;
      authorizedKeys = cfg.public_keys;
      # TODO: Do somehting to make sure these keys exist. Currently wont exist until you ssh somewhere for the first time.
      hostKeys =
        [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
    };
    # use this lspci -v | grep -iA8 'network\|ethernet' to then ask Chad what modules to use here
    boot.initrd.availableKernelModules =
      [ "thunderbolt" "usbnet" "igb" "r8152" "iwlwifi" "igc" "cdc_ether" ];
    boot.kernelParams = [ "ip=dhcp" ];
    boot.kernelModules = [ "e1000e" "alx" "r8169" "igb" "cdc_ether" "r8152" ];
    boot.initrd.kernelModules =
      [ "e1000e" "alx" "r8169" "igb" "cdc_ether" "r8152" ];

    # TODO: Move this somewhere more appropriate or otherwise fix dns
    networking.useDHCP = mkForce true;

    services.zfs.autoSnapshot = { enable = true; };

    # Phase 2 systemd service to unlock pools that imported late (after initrd)
    # This handles the case where HBA/drives are slow to enumerate
    systemd.services.zfs-load-key-tang = {
      description = "Load ZFS keys using Tang/Clevis for late-importing pools";
      after = [ "zfs-import.target" "network-online.target" ];
      before = [ "zfs-mount.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "zfs-mount.service" ];
      
      # Only run if there are pools with unavailable keys
      unitConfig = {
        ConditionPathExists = "/sys/module/zfs";
        DefaultDependencies = false;
      };
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Don't fail the boot if we can't unlock - allow manual unlock
        SuccessExitStatus = "0 1";
      };
      
      path = with pkgs; [ zfs curl clevis gawk coreutils util-linux gnugrep ];
      
      script = zfsUnlockScript;
    };
  };
}
