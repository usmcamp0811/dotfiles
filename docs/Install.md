# Reformat & Install NixOS

If you need a video or something to see this stuff in action checkout these two YouTube videos:

- https://www.youtube.com/live/ADIcVWCoVB4?si=l1a8Iy2nu2DNW5LY

- https://youtu.be/CboOUrkIZ2k?si=rDSyXlYu0EyMbBau

## Boot into the Live USB

```bash
install_drive="/dev/nvme0n1"

# Zap the NVMe drive
sudo sgdisk --zap-all "$install_drive"

# Create a 1GB boot partition
sudo sgdisk -n 1:0:+1G -t 1:EF00 "$install_drive"

# Create a partition for the remaining space
sudo sgdisk -n 2:0:0 -t 2:BF00 "$install_drive"

# Make sure Boot is bootable
sudo parted $install_drive -- set 1 esp on
```


### Boot Partition

```bash
sudo mkfs.fat -F 32 /dev/nvme0n1p1
sudo fatlabel /dev/nvme0n1p1 BOOT
```

The BTRFS and ZFS partitioning below are more or less the same.

*If you aren't encrypting your drive(s)...you are wrong...fix yourself!*

### BTRFS

```bash
# incase your USB doesn't have LUKS
nix shell nixpkgs\#cryptsetup

sudo cryptsetup --batch-mode -c aes-xts-plain64 --use-random luksFormat "/dev/nvme0n1p2"
sudo cryptsetup luksOpen "/dev/nvme0n1p2" luks
nix shell nixpkgs\#btrfs-progs
sudo mkfs.btrfs /dev/mapper/luks
sudo mkdir /mnt 
sudo mount /dev/mapper/luks /mnt
sudo btrfs subvolume create /mnt/root
sudo btrfs subvolume create /mnt/home
sudo btrfs subvolume create /mnt/persist
sudo umount /mnt
sudo mount -o subvol=root,compress=lzo /dev/mapper/luks /mnt
sudo mkdir /mnt/{boot,home,persist}
sudo mount -o subvol=home,compress=lzo /dev/mapper/luks /mnt/home
sudo mount -o subvol=persist,compress=lzo /dev/mapper/luks /mnt/persist
sudo mount /dev/nvme0n1p1 /mnt/boot
```

### ZFS

```bash
sudo zpool export -a
sudo zpool import
sudo zpool create -f \
-o altroot="/mnt" \
-o ashift=12 \
-o autotrim=on \
-O compression=lz4 \
-O acltype=posixacl \
-O xattr=sa \
-O relatime=on \
-O normalization=formD \
-O dnodesize=auto \
-O sync=disabled \
-O encryption=aes-256-gcm \
-O keylocation=prompt \
-O keyformat=passphrase \
-O mountpoint=none \
NIXROOT \
/dev/nvme0n1p2

sudo zfs create -o mountpoint=legacy NIXROOT/root
sudo zfs create -o mountpoint=legacy NIXROOT/home
sudo zfs create -o mountpoint=legacy NIXROOT/persist

# reserved to cope with running out of disk space
sudo zfs create -o refreservation=1G -o mountpoint=none NIXROOT/reserved
sudo mkdir /mnt
sudo mount -t zfs NIXROOT/root /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/home
sudo mkdir /mnt/persist
sudo mount ${install_drive}1 /mnt/boot
sudo mount -t zfs NIXROOT/home /mnt/home
sudo mount -t zfs NIXROOT/persist /mnt/persist
```

## Install 

Generate your `hardware.nix` and create your new system configs by running:

```bash
nixos-generate-config --root /mnt
git clone https://gitlab.com/usmcamp0811/dotfiles.git /mnt/config
```

Make your new system under the correct architecture (likely `x86_64-linux`). If your new system was to be named `carey` then you would:

```bash
mkdir /mnt/config/systems/x86_64-linux/carey
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/config/systems/x86_64-linux/carey/hardware.nix
cp /mnt/config/systems/x86_64-linux/template /mnt/config/systems/x86_64-linux/carey/default.nix
```

You will need to make some modifications to `/mnt/config/systems/x86_64-linux/carey/default.nix`, but don't add things that need secrets from Vault, because we don't have our [approle setup](./SECRETS.md) yet and I don't recommend doing that yet.

You will need to `git add` the new config files so the Flake can see them.

If you are feeling lucky you can install my flake first but I've had spotty luck getting the system to boot first time when I do this. 

```bash
nixos-install --flake /mnt/config#carey
```

So what I suggest is you do:

```bash
nixos-install
nixos-enter
nixos-rebuild boot --flake /config#carey
```
If all went as expected then you should be able to reboot and boot into your new config. If the flake config doesn't boot then just run:

```bash
nixos-rebuild switch --flake /config#carey
```

You should then have the flake config which you can then tweak as you wish.

#### TODO:

- I want to automate this more. Disko is something I want to use but its unclear to me how to do ZFS or BTRFS encrypted with it, and I've had issues being able to boot after using it. 
- I would like to automate the addition of new systems. I think I could probably just write a shell script or something that gets added to the flake and can be run. 
- It would be great to just be able to install from the flake directly, so I probably just need to see what causes the issues with booting this way.
