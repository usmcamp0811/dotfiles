# ZFS Encrypted Root Partition Module for NixOS

This NixOS module enables encrypted ZFS root partitions, featuring options for manual and automated unlocking. Ideal for encrypted storage, remote unlocking, and auto-reboot capabilities.

## Features

- ZFS root partition encryption
- SSH-based manual unlocking
- [Clevis](https://github.com/latchset/clevis) with SSS encryption for automated unlocking
- Configurable `keyfile-url`

## Requirements

- **Host ID**: This is a mandatory parameter for using ZFS. Obtain it by running `head -c 8 /etc/machine-id` during the pre-install phase.

## Usage

Import this module into your main Nix configuration:

```nix
system = {
  zfs = {
    enable = true;
    hostId = "abcd1234";  # Obtain by running `head -c 8 /etc/machine-id`
    keyfile-url = "http://my-your-keyserver.lan/zfs-keyfile";
  };
};
```

## Options

- `enable`: Enables encrypted ZFS root.
- `hostId`: Your machine's host ID. (Obtain by running `head -c 8 /etc/machine-id`)
- `keyfile-url`: URL to fetch the encrypted keyfile.

## Security

Uses [Clevis](https://github.com/latchset/clevis) and SSS for secure automated unlocking. Manual unlocking is required if the system is off-network or unable to access the `keyfile-url`.

### Hosting the Keyfile

Use the `zfs-key-server` module located at `../services/zfs-key-server` to host the encrypted keyfile via an Nginx proxy.

## Example

```nix
system = {
  boot = enabled;
  zfs = {
    enable = true;
    hostId = "65c8b2d7";  # Obtain by running `head -c 8 /etc/machine-id`
    keyfile-url = "http://my-xps:8080/zfs-keyfile";
  };
};
```

## SSH Unlock

For manual unlocking via SSH:

```bash
ssh -p 2222 root@host "zpool import -a; zfs load-key -a && killall zfs"
```

This provides a secure ZFS root partition with options for both manual and automated unlocking.

## Auto Snapshot

Auto Snapshot is enabled automatically with this module but does nothing till you turn it on per dataset.
The default number of snapshots will be retained.

Per dataset you want to snapshot:

```
 sudo zfs set com.sun:auto-snapshot=true <dataset name>
```

