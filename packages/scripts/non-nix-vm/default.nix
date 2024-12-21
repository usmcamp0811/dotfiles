{ pkgs ? import <nixpkgs> { } }:
let
  ubuntu = pkgs.fetchurl {
    url =
      "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-desktop-amd64.iso";
    sha256 = ""; # Replace with actual hash
  };

  vm = pkgs.writeShellScriptBin "start-ubuntu-vm" ''
    # VM Configuration
    VM_NAME="ubuntu-vm"
    IMAGE_PATH="$HOME/${VM_NAME}.qcow2"
    ISO_PATH=${ubuntu}
    MEMORY="4096" # RAM in MB
    VCPUS="2" # Number of virtual CPUs
    DISK_SIZE="30G" # Disk size

    # Check if VM already exists
    if virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "VM $VM_NAME already exists. Starting the VM..."
        virsh start "$VM_NAME"
        exit 0
    fi

    # Create a disk image
    if [ ! -f "$IMAGE_PATH" ]; then
        echo "Creating a disk image at $IMAGE_PATH..."
        qemu-img create -f qcow2 "$IMAGE_PATH" "$DISK_SIZE"
    fi

    # Install and configure the VM
    echo "Creating and starting the VM..."
    virt-install \
        --name="$VM_NAME" \
        --ram="$MEMORY" \
        --vcpus="$VCPUS" \
        --os-variant="ubuntu20.04" \
        --disk path="$IMAGE_PATH",format=qcow2 \
        --cdrom="$ISO_PATH" \
        --graphics=spice \
        --network network=default \
        --noautoconsole

    echo "VM $VM_NAME created successfully."
  '';
in
vm
