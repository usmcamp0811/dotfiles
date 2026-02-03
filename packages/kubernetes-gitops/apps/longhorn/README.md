# Longhorn Storage

## Overview

This directory contains configuration for Longhorn, a cloud-native distributed block storage system for Kubernetes.

## Components

- **storageclass.yaml**: Defines the default StorageClass for dynamic volume provisioning
  - 3 replicas for data redundancy
  - ext4 filesystem
  - Immediate volume binding
  - Volume expansion enabled

## Deployment

Longhorn is deployed via the ArgoCD Application at `clusters/campground/apps/longhorn.yaml` which:
- Installs the Longhorn Helm chart from https://charts.longhorn.io
- References this directory for additional manifests (StorageClass)
- Creates the `longhorn-system` namespace
- Configures automated sync and self-healing

## Features

- Cloud-native distributed block storage
- Built-in backup and restore
- Volume snapshots and cloning
- Cross-cluster disaster recovery
- Storage volume replication
- Web UI for management

## Access

Once deployed, the Longhorn UI is accessible at:
- Through kubectl port-forward: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8000:80`
- Or exposed via an Ingress (if configured)
