# Longhorn Storage

## Overview

This directory contains configuration for Longhorn, a cloud-native distributed block storage system for Kubernetes.

## Components

- **storageclass.yaml**: Defines the default StorageClass for dynamic volume provisioning
  - 3 replicas for data redundancy
  - ext4 filesystem
  - Immediate volume binding
  - Volume expansion enabled

- **nixos-path-configmap.yaml**: ConfigMap with NixOS-specific PATH for Longhorn components
  - Required for Longhorn to find binaries via nsenter on NixOS nodes
  - See: https://github.com/longhorn/longhorn/issues/2166

## Deployment

Longhorn is deployed via the ArgoCD Application at `clusters/campground/apps/longhorn.yaml` which:
- Installs the Longhorn Helm chart v1.9.1 from https://charts.longhorn.io
- References this directory for additional manifests (StorageClass, ConfigMap)
- Creates the `longhorn-system` namespace
- Configures automated sync and self-healing
- Sets NixOS-compatible PATH for longhorn-manager and longhorn-driver components

## NixOS Compatibility

Longhorn requires special configuration to work on NixOS due to non-standard filesystem paths. This is handled at three levels:

### 1. Host-Level Configuration (fmf.services.k3s module)
The k3s NixOS module automatically configures:
- **iSCSI daemon**: `services.openiscsi` with BindPaths for NixOS binaries
- **NFS client**: `nfs-utils`, `rpcbind`, and kernel modules for RWX volumes
- **Encryption support**: `cryptsetup` and `dm_crypt` kernel modules
- **FHS symlinks**: `/usr/bin/iscsiadm`, `/sbin/mount.nfs`, `/sbin/cryptsetup`, etc.
- **Mount propagation**: `rshared` on `/var/lib/kubelet` and `/var/lib/rancher`
- **Kernel config**: Extracted to `/boot/config-$(uname -r)` for Longhorn's environment checker

### 2. Container-Level Configuration (Helm values)
The ArgoCD Application sets custom PATH environment variables for:
- `longhornManager`: Manages volumes and orchestrates instance-manager pods
- `longhornDriver`: CSI driver for volume attachment

### 3. ConfigMap (Defense-in-depth)
The `longhorn-nixos-path` ConfigMap provides the NixOS PATH that can be referenced by other components if needed.

## Features

- Cloud-native distributed block storage
- Built-in backup and restore
- Volume snapshots and cloning
- Cross-cluster disaster recovery
- Storage volume replication (3 replicas default)
- Web UI for management
- **NixOS support**: Full RWO (iSCSI), RWX (NFS), and encrypted volume support

## Access

Once deployed, the Longhorn UI is accessible at:
- Through kubectl port-forward: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8000:80`
- Or exposed via an Ingress (if configured)

## Troubleshooting

### "No such file or directory" errors for iscsiadm or mount.nfs

If you see errors like:
```
failed to execute: nsenter [...] mount.nfs
nsenter: failed to execute mount.nfs: No such file or directory
```

Check:
1. **FHS symlinks exist** on the host: `ls -la /sbin/mount.nfs /usr/bin/iscsiadm`
2. **iscsid BindPaths** is configured: `systemctl show iscsid | grep BindPaths`
3. **Kernel modules loaded**: `lsmod | grep -E "iscsi|nfs"`
4. **Mount propagation**: `findmnt /var/lib/rancher | grep shared`

### Longhorn environment check failures

Longhorn performs environment checks on each node. On NixOS, ensure:
- **openiscsi** is enabled and running: `systemctl status iscsid`
- **Kernel config** is available: `ls /boot/config-$(uname -r)`
- **Required packages** are installed: `which iscsiadm mount.nfs cryptsetup`

All of these are automatically configured by the `fmf.services.k3s` module.
