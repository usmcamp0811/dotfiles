{ pkgs ? import <nixpkgs> { } }:
let
  ubuntu = pkgs.fetchurl {
    url =
      "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-desktop-amd64.iso";
    sha256 =
      "sha256-wub03DeslE4u1Qf4fGGI3U0xeb9KP54RDTyI0fMpS9w="; # Replace with actual hash
  };

  vm = pkgs.writeShellScriptBin "start-ubuntu-vm" ''
    # Hardcoded ISO path (update with your correct path)
    ISO_PATH="${ubuntu}"

    # Default values for arguments
    DISK_PATH="ubuntu-disk.qcow2"
    DISK_SIZE="30G"
    MEMORY="4G"
    CPUS="2"
    SSH_PORT="2322"

    # Print help message
    function print_help {
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --disk-path PATH      Path to the disk image (default: $DISK_PATH)"
        echo "  --disk-size SIZE      Size of the disk image (default: $DISK_SIZE)"
        echo "  --memory SIZE         Amount of memory to allocate (default: $MEMORY)"
        echo "  --cpus NUM            Number of CPU cores to allocate (default: $CPUS)"
        echo "  --ssh-port PORT       Host port to forward for SSH (default: $SSH_PORT)"
        echo "  --help                Display this help message and exit"
    }

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --disk-path)
                DISK_PATH="$2"
                shift 2
                ;;
            --disk-size)
                DISK_SIZE="$2"
                shift 2
                ;;
            --memory)
                MEMORY="$2"
                shift 2
                ;;
            --cpus)
                CPUS="$2"
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --help)
                print_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done

    # Check if ISO file exists
    if [[ ! -f "$ISO_PATH" ]]; then
        echo "ISO file not found at $ISO_PATH. Please update the script with the correct path."
        exit 1
    fi

    # Step 1: Create the disk image
    if [[ ! -f "$DISK_PATH" ]]; then
        echo "Creating disk image at $DISK_PATH with size $DISK_SIZE..."
        qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
    else
        echo "Disk image already exists at $DISK_PATH."
    fi

    # Step 2: Boot from the ISO for installation
    echo "Starting VM to install Ubuntu from ISO..."
    qemu-system-x86_64 \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -boot d \
        -cdrom "$ISO_PATH" \
        -drive file="$DISK_PATH",format=qcow2 \
        -enable-kvm \
        -net nic,model=virtio \
        -net user,hostfwd=tcp::"$SSH_PORT"-:22

    echo "Installation complete. Reboot the VM to start from the installed disk."

    # Step 3: Start the installed VM (manual reboot after installation)
    echo "To start the VM after installation, run:"
    echo "qemu-system-x86_64 \\"
    echo "    -m \"$MEMORY\" \\"
    echo "    -smp \"$CPUS\" \\"
    echo "    -drive file=\"$DISK_PATH\",format=qcow2 \\"
    echo "    -enable-kvm \\"
    echo "    -net nic,model=virtio \\"
    echo "    -net user,hostfwd=tcp::$SSH_PORT-:22"
  '';
in
vm
