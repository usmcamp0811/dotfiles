{ options, config, pkgs, lib, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.system.zfs;

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
    environment.systemPackages = with pkgs; [ clevis ];

    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.requestEncryptionCredentials = true;
    services.zfs.autoScrub.enable = true;
    services.nfs.server.enable = true;

    boot.kernelPackages = pkgs.linuxPackages_6_6;

    networking.hostId = cfg.hostId;

    boot.initrd.network.enable = true;
    boot.initrd.systemd = {
      enable = true;
      
      # Ensure required packages are available in initrd
      storePaths = with pkgs; [ 
        "${curl}/bin/curl"
        "${clevis}/bin/clevis" 
        "${clevis}/bin/clevis-decrypt"
        "${clevis}/bin/clevis-decrypt-tang"
        "${gawk}/bin/gawk"
        "${gawk}/bin/awk"
        "${zfs}/bin/zfs"
        "${zfs}/bin/zpool"
        "${coreutils}/bin/coreutils"
        "${coreutils}/bin/sleep"
        "${coreutils}/bin/echo"
        "${coreutils}/bin/printf"
        "${coreutils}/bin/wc"
        "${util-linux}/bin/killall"
      ];

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
        path = with pkgs; [ curl clevis gawk zfs ];
        serviceConfig.Type = "oneshot";
        script = ''
        # Set PATH to include all required binaries
        export PATH="${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.clevis}/bin:${pkgs.gawk}/bin:${pkgs.zfs}/bin:${pkgs.util-linux}/bin:$PATH"
        
        log() {
          echo "[ZFS Unlock] $1"
        }

        log "Initrd unlock service started"
        log "Sleeping 5 seconds to wait for network and Tang server"
        sleep 5
        
        log "Importing all ZFS pools"
        zpool import -a
        IMPORT_STATUS=$?
        log "zpool import -a exited with status $IMPORT_STATUS"

        # Retrieve and decrypt the passphrase with retry logic
        log "Fetching encrypted keyfile from ${cfg.keyfile-url}"
        ENCRYPTED_KEYFILE=""
        RETRY_COUNT=0
        MAX_RETRIES=3
        
        while [ -z "$ENCRYPTED_KEYFILE" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
          ENCRYPTED_KEYFILE=$(curl -s -f --connect-timeout 5 --max-time 10 ${cfg.keyfile-url})
          CURL_STATUS=$?
          log "curl attempt $((RETRY_COUNT + 1)) exited with status $CURL_STATUS"
          if [ -z "$ENCRYPTED_KEYFILE" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            log "Failed to fetch non-empty keyfile (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 3 seconds"
            sleep 3
          fi
        done
        
        if [ -z "$ENCRYPTED_KEYFILE" ]; then
          log "ERROR: Failed to fetch encrypted keyfile after $MAX_RETRIES attempts"
          log "Network may not be ready or Tang server may be unreachable"
          log "You can unlock manually via SSH or at the console prompt"
        else
          log "Keyfile retrieved successfully (\$(printf '%s' \"\$ENCRYPTED_KEYFILE\" | wc -c) bytes), decrypting with Clevis/Tang"
          
          # Decrypt the keyfile
          export PASSPHRASE="$(echo "$ENCRYPTED_KEYFILE" | ${pkgs.clevis}/bin/clevis decrypt 2>&1)"
          DECRYPT_STATUS=$?
          log "clevis decrypt exited with status $DECRYPT_STATUS"
          
          if [ $DECRYPT_STATUS -ne 0 ]; then
            log "ERROR: Clevis decryption failed with status $DECRYPT_STATUS"
            log "Tang server may be unavailable or keyfile may be corrupted"
            log "You can unlock manually via SSH or at the console prompt"
            unset PASSPHRASE
          elif [ -z "$PASSPHRASE" ]; then
            log "ERROR: Decrypted passphrase is empty"
            log "You can unlock manually via SSH or at the console prompt"
          else
            log "Decryption successful, discovering locked datasets"
            
            # Load the key for each encrypted ZFS dataset
            UNLOCK_SUCCESS=0
            UNLOCK_FAILED=0
            LOCKED_DATASETS=$(zfs get keystatus -H -o name,value -t filesystem,volume | grep "unavailable" | awk '{print $1}' || true)
            if [ -z "$LOCKED_DATASETS" ]; then
              log "No locked datasets found after decryption"
            else
              log "Locked datasets to unlock: $LOCKED_DATASETS"
            fi
            
            for dataset in $LOCKED_DATASETS
            do
              log "Loading key for: $dataset"
              # Use -L prompt to override the dataset's keylocation property
              # This allows us to pipe the passphrase regardless of the stored keylocation value
              if echo -n "$PASSPHRASE" | zfs load-key -L prompt "$dataset" 2>&1; then
                UNLOCK_SUCCESS=$((UNLOCK_SUCCESS + 1))
                log "Successfully loaded key for $dataset"
              else
                UNLOCK_FAILED=$((UNLOCK_FAILED + 1))
                log "WARNING: Failed to load key for $dataset"
              fi
            done
            
            log "Summary: $UNLOCK_SUCCESS datasets unlocked successfully, $UNLOCK_FAILED failed"
            
            # Clear passphrase from memory
            unset PASSPHRASE
            unset ENCRYPTED_KEYFILE
          fi
        fi

        log "Calling killall zfs to continue boot"
        killall zfs
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
      
      path = with pkgs; [ zfs curl clevis gawk coreutils util-linux ];
      
      script = ''
        set +e  # Don't exit on error, we want to try all datasets
        log() {
          echo "[ZFS Phase2 Unlock] $1"
        }
        
        log "Checking for encrypted datasets with unavailable keys"
        
        # Get list of locked encryption roots (not child datasets)
        LOCKED_ROOTS=$(zfs get -H -o name,value,source encryptionroot,keystatus -t filesystem,volume \
          | awk '$2 == $1 && $4 == "unavailable" {print $1}' \
          | sort -u)
        
        if [ -z "$LOCKED_ROOTS" ]; then
          log "No locked encryption roots found, all keys already loaded"
          exit 0
        fi
        
        LOCKED_COUNT=$(echo "$LOCKED_ROOTS" | wc -l)
        log "Found $LOCKED_COUNT locked encryption roots: $LOCKED_ROOTS"
        log "Fetching encrypted keyfile from ${cfg.keyfile-url}"
        
        # Create secure tmpfs location for passphrase (root-only, in-memory)
        KEYFILE_DIR=$(mktemp -d -p /run zfs-unlock.XXXXXX)
        chmod 700 "$KEYFILE_DIR"
        KEYFILE_PATH="$KEYFILE_DIR/passphrase"
        
        # Ensure cleanup on exit
        trap "shred -u '$KEYFILE_PATH' 2>/dev/null || rm -f '$KEYFILE_PATH'; rmdir '$KEYFILE_DIR' 2>/dev/null" EXIT
        
        # Fetch and decrypt with retry logic - stream directly to avoid shell variable
        RETRY_COUNT=0
        MAX_RETRIES=3
        DECRYPT_SUCCESS=0
        
        while [ $DECRYPT_SUCCESS -eq 0 ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
          if ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 ${cfg.keyfile-url} \
             | ${pkgs.clevis}/bin/clevis decrypt > "$KEYFILE_PATH" 2>/dev/null; then
            DECRYPT_SUCCESS=1
            log "Fetch/decrypt attempt $((RETRY_COUNT + 1)) succeeded"
          else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
              log "Failed to fetch/decrypt keyfile (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 3 seconds"
              sleep 3
            fi
          fi
        done
        
        if [ $DECRYPT_SUCCESS -eq 0 ]; then
          log "ERROR: Failed to fetch/decrypt keyfile after $MAX_RETRIES attempts"
          log "Manual unlock required via: zfs load-key -a"
          exit 1
        fi
        
        # Verify we got a non-empty passphrase
        if [ ! -s "$KEYFILE_PATH" ]; then
          log "ERROR: Decrypted passphrase is empty"
          log "Manual unlock required via: zfs load-key -a"
          exit 1
        fi
        
        log "Decryption successful, loading keys for encryption roots"
        
        # Load keys for all locked encryption roots
        UNLOCK_SUCCESS=0
        UNLOCK_FAILED=0
        
        for dataset in $LOCKED_ROOTS
        do
          log "Loading key for encryption root: $dataset"
          if zfs load-key -L prompt "$dataset" < "$KEYFILE_PATH" 2>&1; then
            UNLOCK_SUCCESS=$((UNLOCK_SUCCESS + 1))
            log "Successfully loaded key for $dataset"
          else
            UNLOCK_FAILED=$((UNLOCK_FAILED + 1))
            log "WARNING: Failed to load key for $dataset"
          fi
        done
        
        log "Summary: $UNLOCK_SUCCESS encryption roots unlocked, $UNLOCK_FAILED failed"
        
        # Cleanup happens via trap
        
        # Return success if at least some datasets were unlocked, or if none were needed
        if [ $UNLOCK_SUCCESS -gt 0 ] || [ $LOCKED_COUNT -eq 0 ]; then
          exit 0
        else
          # Failed to unlock anything, but don't block boot
          exit 1
        fi
      '';
    };
  };
}
