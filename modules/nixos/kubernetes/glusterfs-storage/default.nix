{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.modules.glusterfs-storage;
in {
  options.fmf.services.k3s.modules.glusterfs-storage = {
    enable = mkEnableOption "Deploy GlusterFS StorageClass using native volume plugin";

    volumeName = mkOption {
      type = types.str;
      default = "kubernetes";
      description = "Name of the GlusterFS volume to use";
    };

    servers = mkOption {
      type = types.listOf types.str;
      default = ["10.8.0.176" "10.8.0.189"]; # reckless, lucas
      description = "List of GlusterFS server IPs";
    };

    namespace = mkOption {
      type = types.str;
      default = "glusterfs-storage";
      description = "Namespace for GlusterFS resources";
    };

    storageClassName = mkOption {
      type = types.str;
      default = "glusterfs";
      description = "Name of the StorageClass";
    };

    isDefault = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this should be the default StorageClass";
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # Namespace for GlusterFS resources
      glusterfs-namespace.content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = cfg.namespace;
      };

      # Endpoints for GlusterFS servers
      glusterfs-endpoints.content = {
        apiVersion = "v1";
        kind = "Endpoints";
        metadata = {
          name = "glusterfs-cluster";
          namespace = cfg.namespace;
        };
        subsets = [{
          addresses = map (ip: { inherit ip; }) cfg.servers;
          ports = [{ port = 1; }]; # Dummy port
        }];
      };

      # Headless service for GlusterFS
      glusterfs-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "glusterfs-cluster";
          namespace = cfg.namespace;
        };
        spec = {
          clusterIP = "None";
          ports = [{ port = 1; }];
        };
      };

      # StorageClass - uses manual provisioning with GlusterFS volumes
      # Users will create PersistentVolumes manually that reference this StorageClass
      glusterfs-storageclass.content = {
        apiVersion = "storage.k8s.io/v1";
        kind = "StorageClass";
        metadata = {
          name = cfg.storageClassName;
          annotations = mkIf cfg.isDefault {
            "storageclass.kubernetes.io/is-default-class" = "true";
          };
        };
        # No automatic provisioner - manual PV creation
        provisioner = "kubernetes.io/no-provisioner";
        volumeBindingMode = "WaitForFirstConsumer";
        reclaimPolicy = "Retain";
      };

      # Example PersistentVolume showing how to use GlusterFS
      # This creates a 100Gi volume backed by your GlusterFS cluster
      glusterfs-example-pv.content = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata.name = "glusterfs-pv-example";
        spec = {
          capacity.storage = "100Gi";
          accessModes = [ "ReadWriteMany" ];
          persistentVolumeReclaimPolicy = "Retain";
          storageClassName = cfg.storageClassName;
          glusterfs = {
            endpoints = "glusterfs-cluster";
            path = cfg.volumeName;
            readOnly = false;
          };
          # Reference to the endpoints in the same namespace
          claimRef = null; # Available for any claim
        };
      };
    };
  };
}
