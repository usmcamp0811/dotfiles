{ lib
, config
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.glusterfs;
in
{
  options.campground.services.glusterfs = {
    enable = lib.mkEnableOption "GlusterFS server";
    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "GlusterFS peers.";
    };
    volumes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Volume name";
          };
          brickDirs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Bricks for this volume";
          };
          replicaCount = lib.mkOption {
            type = lib.types.int;
            default = 2;
            description = "Replica count";
          };
          transport = lib.mkOption {
            type = lib.types.str;
            default = "tcp";
            description = "Transport type (tcp or rdma)";
          };
        };
      });
      default = [ ];
      description = "List of GlusterFS volumes to create.";
    };
  };

  config = mkIf cfg.enable {
    services.glusterfs = {
      enable = true;
      useRpcbind = true;
    };

    systemd.services.glusterfs-volume-create = {
      description = "Create GlusterFS Volumes";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "glusterd.service" ];
      serviceConfig = {
        Type = "oneshot";
        Path = [ pkgs.glusterfs ];
      };
      script =
        ''
          set -e
          peers=(${lib.concatStringsSep " " cfg.peers})
          for peer in "''${peers[@]}"; do
            gluster peer probe $peer || true
          done
        ''
        + lib.concatMapStringsSep "\n"
          (vol:
            let
              bricks = lib.concatMapStringsSep " " (dir: "${config.networking.hostName}:${dir}") vol.brickDirs;
            in
            ''
              gluster volume create ${vol.name} \
                replica ${toString vol.replicaCount} \
                transport ${vol.transport} \
                ${bricks} force || true
              gluster volume start ${vol.name} || true
            '')
          cfg.volumes;
    };

    networking.firewall.allowedTCPPorts = [ 24007 24008 24009 49152 49153 ];
  };
}
