# GlusterFS NixOS Module

This module configures a GlusterFS server using a declarative interface under `campground.services.glusterfs`.

## Features

- Enables the GlusterFS service on NixOS
- Automatically peers with other GlusterFS nodes
- Creates and starts GlusterFS volumes if not already present
- Validates brick paths for local volumes
- Supports multiple volumes, replica count, and transport type
- Sets required firewall ports

## Options

```nix
campground.services.glusterfs = {
  enable = true;

  peers = [ "peer1" "peer2" ]; # List of peer hostnames

  volumes = [
    {
      name = "gv0";
      brickDirs = [ "/data/glusterfs/brick1" "/data/glusterfs/brick2" ];
      replicaCount = 2;
      transport = "tcp"; # or "rdma"
    }
  ];
};
```

## Bootstrapping Instructions

When deploying a new GlusterFS volume for the first time:

1. **Deploy the configuration to a single node only**, with an **empty `peers` list**.
2. This node will initialize the volume and perform brick validation.
3. Once the initial deployment is complete and the volume is created, deploy the same configuration to the other nodes with the `peers` list populated.
4. The additional nodes will peer with the bootstrap node and join the cluster.

> **Note:** Brick paths must already exist on the bootstrap node, or volume creation will be skipped.

## Firewall

The following ports are automatically opened:

- TCP: 24007, 24008, 24009, 49152, 49153
