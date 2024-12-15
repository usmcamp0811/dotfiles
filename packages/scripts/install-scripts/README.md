# Install Scripts for NixOS Installation

This package provides a collection of scripts to automate the partitioning and formatting of drives for NixOS installations, with support for Btrfs and ZFS. These scripts simplify the setup process, incorporating encryption and filesystem configurations tailored for NixOS.

## Features

- **Partition Script**: Automates the creation of boot and data partitions.
- **Btrfs Formatting**: Sets up encrypted Btrfs with subvolumes for `root`, `home`, and `persist`.
- **ZFS Formatting**: Configures an encrypted ZFS pool with best practices for performance and reliability.
- **Helper Scripts**: Combines partitioning and formatting steps for both Btrfs and ZFS into single commands.

---

## Installation

Clone this repository and build the derivation to install the scripts:

```bash
nix-build
```

After building, the scripts will be available in the resulting `result/bin` directory.

---

## Scripts

### 1. **Partition Script**

This script partitions a drive into:

- A 1GB boot partition (ESP).
- The remaining space for an encrypted data partition.

#### Usage

```bash
partition [DRIVE]
```

- **`DRIVE`**: The target drive (e.g., `/dev/nvme0n1`). Defaults to `/dev/nvme0n1` if not specified.

---

### 2. **Btrfs Formatting**

This script sets up an encrypted Btrfs filesystem on the data partition.

#### Steps Automated:

1. Format the data partition with LUKS encryption.
2. Create and mount Btrfs subvolumes: `root`, `home`, and `persist`.
3. Mount the boot partition.

#### Usage

```bash
format-btrfs [DRIVE]
```

- **`DRIVE`**: The target drive (e.g., `/dev/nvme0n1`). Defaults to `/dev/nvme0n1` if not specified.

---

### 3. **ZFS Formatting**

This script configures an encrypted ZFS pool with custom settings.

#### Steps Automated:

1. Export and import any existing ZFS pools.
2. Create a new encrypted ZFS pool with best practices.
3. Create ZFS datasets for `root`, `home`, and `persist`.
4. Reserve space to handle low disk space scenarios.
5. Mount ZFS datasets and the boot partition.

#### Usage

```bash
format-zfs [DRIVE]
```

- **`DRIVE`**: The target drive (e.g., `/dev/nvme0n1`). Defaults to `/dev/nvme0n1` if not specified.

---

### 4. **Helper Scripts**

- **`zfs-setup`**: Combines the partitioning and ZFS formatting steps.
  ```bash
  zfs-setup [DRIVE]
  ```
- **`btrfs-setup`**: Combines the partitioning and Btrfs formatting steps.
  ```bash
  btrfs-setup [DRIVE]
  ```

---

## Installation Process Overview

1. Boot into the NixOS live environment.
2. Use the `partition` script to partition your drive.
3. Choose your filesystem setup:
   - For **Btrfs**: Run `btrfs-setup`.
   - For **ZFS**: Run `zfs-setup`.
4. Install NixOS:
   - Generate your hardware configuration:
     ```bash
     nixos-generate-config --root /mnt
     ```
   - Clone your NixOS configuration:
     ```bash
     git clone https://gitlab.com/usmcamp0811/dotfiles.git /mnt/config
     ```
   - Install NixOS:
     ```bash
     nixos-install --flake /mnt/config#<system-name>
     ```

---

## Notes

- **Encryption**: All data partitions are encrypted with LUKS or ZFS native encryption.
- **Flexibility**: The scripts are designed with defaults but allow for customization via arguments.
- **Best Practices**: Filesystem settings prioritize performance, compression, and data integrity.

---

## TODO

1. Automate new system addition to the configuration flake.
2. Simplify direct installation from the flake.
3. Explore `disko` for further automation of ZFS and Btrfs setups.

For questions or updates, refer to the [GitLab Repository](https://gitlab.com/usmcamp0811/dotfiles.git).
