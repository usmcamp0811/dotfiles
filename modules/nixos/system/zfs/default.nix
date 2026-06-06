{ options, config, pkgs, lib, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.system.zfs;
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

    boot.initrd.network = {
      enable = true;
      postCommands = ''
        # Extended initial delay for network and Tang server to be ready
        sleep 5
        export PATH="${pkgs.curl}/bin:${pkgs.clevis}/bin:${pkgs.gawk}/bin:$PATH"
        
        echo "[ZFS Unlock] Importing all ZFS pools..."
        zpool import -a;

        # Retrieve and decrypt the passphrase with retry logic
        echo "[ZFS Unlock] Fetching encrypted keyfile from ${cfg.keyfile-url}..."
        ENCRYPTED_KEYFILE=""
        RETRY_COUNT=0
        MAX_RETRIES=3
        
        while [ -z "$ENCRYPTED_KEYFILE" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
          ENCRYPTED_KEYFILE=$(${pkgs.curl}/bin/curl -s -f --connect-timeout 5 --max-time 10 ${cfg.keyfile-url})
          if [ -z "$ENCRYPTED_KEYFILE" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "[ZFS Unlock] Failed to fetch keyfile (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 3 seconds..."
            sleep 3
          fi
        done
        
        if [ -z "$ENCRYPTED_KEYFILE" ]; then
          echo "[ZFS Unlock] ERROR: Failed to fetch encrypted keyfile after $MAX_RETRIES attempts"
          echo "[ZFS Unlock] Network may not be ready or Tang server may be unreachable"
          echo "[ZFS Unlock] You can unlock manually via SSH or at the console prompt"
        else
          echo "[ZFS Unlock] Keyfile retrieved successfully, decrypting with Clevis/Tang..."
          
          # Decrypt the keyfile
          export PASSPHRASE="$(echo "$ENCRYPTED_KEYFILE" | ${pkgs.clevis}/bin/clevis decrypt 2>&1)"
          DECRYPT_STATUS=$?
          
          if [ $DECRYPT_STATUS -ne 0 ]; then
            echo "[ZFS Unlock] ERROR: Clevis decryption failed with status $DECRYPT_STATUS"
            echo "[ZFS Unlock] Tang server may be unavailable or keyfile may be corrupted"
            echo "[ZFS Unlock] You can unlock manually via SSH or at the console prompt"
            unset PASSPHRASE
          elif [ -z "$PASSPHRASE" ]; then
            echo "[ZFS Unlock] ERROR: Decrypted passphrase is empty"
            echo "[ZFS Unlock] You can unlock manually via SSH or at the console prompt"
          else
            echo "[ZFS Unlock] Decryption successful, loading keys into ZFS..."
            
            # Load the key for each encrypted ZFS dataset
            UNLOCK_SUCCESS=0
            UNLOCK_FAILED=0
            
            for dataset in $(zfs get keystatus -H -o name,value -t filesystem,volume | grep "unavailable" | awk '{print $1}')
            do
              echo "[ZFS Unlock] Loading key for: $dataset"
              # Use -L prompt to override the dataset's keylocation property
              # This allows us to pipe the passphrase regardless of the stored keylocation value
              if echo -n "$PASSPHRASE" | zfs load-key -L prompt "$dataset" 2>&1; then
                UNLOCK_SUCCESS=$((UNLOCK_SUCCESS + 1))
              else
                UNLOCK_FAILED=$((UNLOCK_FAILED + 1))
                echo "[ZFS Unlock] WARNING: Failed to load key for $dataset"
              fi
            done
            
            echo "[ZFS Unlock] Summary: $UNLOCK_SUCCESS datasets unlocked successfully, $UNLOCK_FAILED failed"
            
            # Clear passphrase from memory
            unset PASSPHRASE
            unset ENCRYPTED_KEYFILE
          fi
        fi

        killall zfs
      '';
      ssh = {
        enable = true;
        port = 22;
        authorizedKeys = cfg.public_keys;
        # TODO: Do somehting to make sure these keys exist. Currently wont exist until you ssh somewhere for the first time.
        hostKeys =
          [ "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
      };
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
        
        echo "[ZFS Phase2 Unlock] Checking for encrypted datasets with unavailable keys..."
        
        # Get list of locked encryption roots (not child datasets)
        LOCKED_ROOTS=$(zfs get -H -o name,value,source encryptionroot,keystatus -t filesystem,volume \
          | awk '$2 == $1 && $4 == "unavailable" {print $1}' \
          | sort -u)
        
        if [ -z "$LOCKED_ROOTS" ]; then
          echo "[ZFS Phase2 Unlock] No locked encryption roots found, all keys already loaded"
          exit 0
        fi
        
        LOCKED_COUNT=$(echo "$LOCKED_ROOTS" | wc -l)
        echo "[ZFS Phase2 Unlock] Found $LOCKED_COUNT locked encryption roots, attempting unlock..."
        echo "[ZFS Phase2 Unlock] Fetching encrypted keyfile from ${cfg.keyfile-url}..."
        
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
          if curl -fsSL --connect-timeout 5 --max-time 10 ${cfg.keyfile-url} \
             | clevis decrypt > "$KEYFILE_PATH" 2>/dev/null; then
            DECRYPT_SUCCESS=1
          else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
              echo "[ZFS Phase2 Unlock] Failed to fetch/decrypt keyfile (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 3 seconds..."
              sleep 3
            fi
          fi
        done
        
        if [ $DECRYPT_SUCCESS -eq 0 ]; then
          echo "[ZFS Phase2 Unlock] ERROR: Failed to fetch/decrypt keyfile after $MAX_RETRIES attempts"
          echo "[ZFS Phase2 Unlock] Manual unlock required via: zfs load-key -a"
          exit 1
        fi
        
        # Verify we got a non-empty passphrase
        if [ ! -s "$KEYFILE_PATH" ]; then
          echo "[ZFS Phase2 Unlock] ERROR: Decrypted passphrase is empty"
          echo "[ZFS Phase2 Unlock] Manual unlock required via: zfs load-key -a"
          exit 1
        fi
        
        echo "[ZFS Phase2 Unlock] Decryption successful, loading keys for encryption roots..."
        
        # Load keys for all locked encryption roots
        UNLOCK_SUCCESS=0
        UNLOCK_FAILED=0
        
        for dataset in $LOCKED_ROOTS
        do
          echo "[ZFS Phase2 Unlock] Loading key for encryption root: $dataset"
          if zfs load-key -L prompt "$dataset" < "$KEYFILE_PATH" 2>&1; then
            UNLOCK_SUCCESS=$((UNLOCK_SUCCESS + 1))
          else
            UNLOCK_FAILED=$((UNLOCK_FAILED + 1))
            echo "[ZFS Phase2 Unlock] WARNING: Failed to load key for $dataset"
          fi
        done
        
        echo "[ZFS Phase2 Unlock] Summary: $UNLOCK_SUCCESS encryption roots unlocked, $UNLOCK_FAILED failed"
        
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
