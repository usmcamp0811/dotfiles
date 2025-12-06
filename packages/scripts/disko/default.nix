{
  lib,
  pkgs,
  stdenv,
  ...
}: let
  # Path to the flake source (this will be a path in the nix store)
  flakeSrc = ../..; # Relative to packages/disko/default.nix -> flake root

  # Main disko runner script
  diskoScript = pkgs.writeShellApplication {
    name = "disko-runner";
    runtimeInputs = with pkgs; [nix git coreutils];
    text = ''
      set -euo pipefail

      # Flake source from nix store (set at build time)
      FLAKE_ROOT="${flakeSrc}"

      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m' # No Color

      show_help() {
        cat << 'EOF'
      ╔═══════════════════════════════════════════════════════════════╗
      ║                     Disko System Installer                    ║
      ╚═══════════════════════════════════════════════════════════════╝

      Declarative disk partitioning for NixOS systems.

      Usage:
        disko [SYSTEM_NAME] [OPTIONS]

      Options:
        --help              Show this help message
        --mode MODE         Disko mode (disko, format, mount, dryDisko)
                           Default: disko
        --encrypted         Use encrypted disko config (disko-encrypted.nix)
        --disk DEVICE       Override disk device (default: /dev/sda)

      Available Systems:
        blue-ridge         Intel N100 Router (238G SSD)
                           Config: systems/x86_64-linux/blue-ridge/disko.nix

      Examples:
        # Show help
        nix run .#disko

        # Partition blue-ridge system
        nix run .#disko -- blue-ridge

        # Use encrypted config
        nix run .#disko -- blue-ridge --encrypted

        # Dry run (show what would be done)
        nix run .#disko -- blue-ridge --mode dryDisko

        # Use different disk
        nix run .#disko -- blue-ridge --disk /dev/nvme0n1

      Notes:
        - This will ERASE ALL DATA on the target disk!
        - Run with --mode dryDisko first to verify
        - For encrypted configs, you'll need to generate a key first
        - After disko completes, run: mkdir -p /mnt/persist/{system,home}

      System Configs:
        Disko configs are stored in: systems/x86_64-linux/{system}/disko.nix
        Encrypted configs:           systems/x86_64-linux/{system}/disko-encrypted.nix

      EOF
      }

      # Parse arguments
      SYSTEM_NAME=""
      MODE="disko"
      ENCRYPTED=false
      DISK_OVERRIDE=""

      while [[ $# -gt 0 ]]; do
        case $1 in
          --help|-h)
            show_help
            exit 0
            ;;
          --mode)
            MODE="$2"
            shift 2
            ;;
          --encrypted)
            ENCRYPTED=true
            shift
            ;;
          --disk)
            DISK_OVERRIDE="$2"
            shift 2
            ;;
          *)
            if [[ -z "$SYSTEM_NAME" ]]; then
              SYSTEM_NAME="$1"
            else
              echo -e "''${RED}Error: Unknown argument: $1''${NC}"
              exit 1
            fi
            shift
            ;;
        esac
      done

      # Show help if no system specified
      if [[ -z "$SYSTEM_NAME" ]]; then
        show_help
        exit 0
      fi

      echo -e "''${GREEN}Using flake from: $FLAKE_ROOT''${NC}"

      # Determine disko config path
      if [[ "$ENCRYPTED" == true ]]; then
        DISKO_CONFIG="$FLAKE_ROOT/systems/x86_64-linux/$SYSTEM_NAME/disko-encrypted.nix"
      else
        DISKO_CONFIG="$FLAKE_ROOT/systems/x86_64-linux/$SYSTEM_NAME/disko.nix"
      fi

      # Check if config exists
      if [[ ! -f "$DISKO_CONFIG" ]]; then
        echo -e "''${RED}Error: Disko config not found: $DISKO_CONFIG''${NC}"
        echo ""
        echo "Available systems:"
        for system_dir in "$FLAKE_ROOT/systems/x86_64-linux"/*; do
          if [[ -d "$system_dir" ]]; then
            system=$(basename "$system_dir")
            if [[ -f "$system_dir/disko.nix" ]] || [[ -f "$system_dir/disko-encrypted.nix" ]]; then
              echo "  - $system"
            fi
          fi
        done
        exit 1
      fi

      echo -e "''${GREEN}Using config: $DISKO_CONFIG''${NC}"
      echo -e "''${GREEN}Mode: $MODE''${NC}"

      # Show current disks
      echo ""
      echo -e "''${YELLOW}Current disk layout:''${NC}"
      lsblk
      echo ""

      # Confirm for destructive operations
      if [[ "$MODE" == "disko" ]] || [[ "$MODE" == "format" ]]; then
        if [[ -z "$DISK_OVERRIDE" ]]; then
          # Extract disk from config
          DISK=$(grep -oP 'device = "/dev/\K[^"]+' "$DISKO_CONFIG" | head -1)
          DISK="/dev/$DISK"
        else
          DISK="$DISK_OVERRIDE"
        fi

        echo -e "''${RED}WARNING: This will ERASE ALL DATA on $DISK!''${NC}"
        echo ""
        read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
        echo
        if [[ ! $REPLY == "yes" ]]; then
          echo "Aborted."
          exit 1
        fi

        # For encrypted config, check for key file
        if [[ "$ENCRYPTED" == true ]]; then
          if [[ ! -f "/tmp/persist.key" ]]; then
            echo -e "''${YELLOW}No encryption key found at /tmp/persist.key''${NC}"
            echo "Generating encryption key..."
            dd if=/dev/random of=/tmp/persist.key bs=1024 count=4
            chmod 600 /tmp/persist.key
            echo ""
            echo -e "''${GREEN}Encryption key generated at /tmp/persist.key''${NC}"
            echo -e "''${RED}IMPORTANT: Backup this key! Without it, your data is UNRECOVERABLE!''${NC}"
            echo ""
            echo "Key contents (save this somewhere safe):"
            base64 /tmp/persist.key
            echo ""
            read -p "Press Enter after you've saved the key..."
          else
            echo -e "''${GREEN}Using existing encryption key: /tmp/persist.key''${NC}"
          fi
        fi
      fi

      # Run disko
      echo ""
      echo -e "''${GREEN}Running disko with mode: $MODE''${NC}"
      echo ""

      if ! nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
        --mode "$MODE" \
        "$DISKO_CONFIG"; then
        echo -e "''${RED}Disko failed!''${NC}"
        exit 1
      fi

      echo ""
      echo -e "''${GREEN}✓ Disko completed successfully!''${NC}"

      # Post-disko instructions
      if [[ "$MODE" == "disko" ]]; then
        echo ""
        echo -e "''${GREEN}Next steps:''${NC}"
        echo "1. Create persist directories:"
        echo "   mkdir -p /mnt/persist/system"
        echo "   mkdir -p /mnt/persist/home/$USER"
        echo ""

        if [[ "$ENCRYPTED" == true ]]; then
          echo "2. Copy encryption key to boot:"
          echo "   cp /tmp/persist.key /mnt/boot/persist.key"
          echo "   chmod 600 /mnt/boot/persist.key"
          echo ""
          echo "3. Install NixOS:"
        else
          echo "2. Install NixOS:"
        fi
        echo "   nixos-install --flake $FLAKE_ROOT#$SYSTEM_NAME"
        echo ""
        echo "4. Reboot:"
        echo "   reboot"
      fi
    '';
  };
in
  # Return the script as a runnable package
  diskoScript
