### NixOS Configuration Tutorial: ZFS Encrypted Root with Auto Unlock

This tutorial explains how to set up an encrypted ZFS root partition on NixOS that auto-unlocks using Clevis. The guide focuses on the essential elements for such a system setup.

#### Environment and Packages

```nix
environment.systemPackages = with pkgs; [
  clevis
];
```
- **`environment.systemPackages`**: Adds the Clevis package for automatic disk decryption to the system environment.

#### Boot Configuration

```nix
boot.supportedFilesystems = [ "zfs" ];
boot.zfs.requestEncryptionCredentials = true;
```
- **`boot.supportedFilesystems`**: Specifies the filesystem types that the system can support. ZFS is necessary for this setup.
- **`boot.zfs.requestEncryptionCredentials`**: Makes sure that ZFS will ask for encryption credentials during boot.

#### ZFS Auto Scrubbing

```nix
services.zfs.autoScrub.enable = true;
```
- **`services.zfs.autoScrub.enable`**: Enables automatic ZFS scrubbing, helping to maintain data integrity.

#### Network Host ID for ZFS

```nix
networking.hostId = "exampleHostId";
```
- **`networking.hostId`**: Sets a unique host ID, which is mandatory for ZFS operations. Obtain this by running `head -c 8 /etc/machine-id`.

#### Network Initialization

```nix
boot.initrd.network = {
  enable = true;
  postCommands = ''
    export PATH="${pkgs.curl}/bin:${pkgs.clevis}/bin:$PATH"
    zpool import -a;
    echo $(curl -s "http://your-keyfile-server.lan/the-encrypted-keyfile" | clevis decrypt) | zfs load-key -a && killall zfs
  '';
};
```
- **`boot.initrd.network.enable`**: Enables network support during the initial RAM disk stage.
- **`postCommands`**: Commands executed after networking is initialized; these import the ZFS pools and decrypt the disk.

#### SSH Configuration

```nix
ssh = {
  enable = true;
  port = 22;
  authorizedKeys = [ ... ];
  hostKeys = [ ... ];
};
```
- **`ssh.enable`**: Activates the SSH server during the initial RAM disk stage.
- **`port`**: The port on which the SSH server listens.
- **`authorizedKeys`** and **`hostKeys`**: Specifies the allowed public keys and SSH host keys, respectively.

#### Kernel Modules

```nix
boot.initrd.availableKernelModules = [ "iwlwifi" "igc" "cdc_ether" ];
boot.kernelParams = [ "ip=dhcp" ];
boot.kernelModules = [ "r8169" "cdc_ether" ];
boot.initrd.kernelModules = [ "r8169" "cdc_ether" ];
```
- **`availableKernelModules`**: Lists kernel modules available during the initial RAM disk stage.
- **`kernelParams`**: Kernel boot parameters.
- **`kernelModules`** and **`initrd.kernelModules`**: Specifies which kernel modules to load.

#### DHCP Configuration

```nix
networking.useDHCP = true;
```
- **`networking.useDHCP`**: Enables DHCP for network configuration.

This tutorial outlines how to create a NixOS configuration that supports an encrypted ZFS root partition with Clevis for automatic unlocking. The tutorial focuses on the general steps and elements you'll need, rather than any specific user's setup.
