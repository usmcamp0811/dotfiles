# Storage Configuration

## Current State

This directory is a placeholder for GlusterFS CSI driver deployment.

## TODO: Implement Gluster CSI Driver

The spec requires using a proper CSI driver instead of the deprecated in-tree GlusterFS plugin.

### Options for Gluster CSI

1. **Kadalu CSI** (https://github.com/kadalu/kadalu)
   - Simple GlusterFS CSI driver
   - Good for small deployments
   - Actively maintained

2. **GlusterFS CSI Driver** (https://github.com/gluster/glusterfs-csi-driver)
   - Official CSI driver
   - More complex setup
   - May have maintenance concerns

### Current Implementation

The existing implementation in `modules/nixos/kubernetes/glusterfs-storage/default.nix` uses:
- Native k8s GlusterFS volume plugin (deprecated)
- Manual provisioning (no dynamic PV creation)
- Endpoints + headless Service pointing to Gluster servers at 10.8.0.176, 10.8.0.189

### Migration Path

1. Choose CSI driver (recommend Kadalu for simplicity)
2. Deploy CSI driver via Helm chart or manifests
3. Create StorageClass using the CSI driver
4. Annotate as default StorageClass
5. Test dynamic PVC provisioning
6. Migrate existing PVs (if any)

### Temporary Solution

For now, this Application deploys basic Gluster endpoints and a manual StorageClass to maintain compatibility with existing workloads.

This should be replaced with a proper CSI driver implementation.
