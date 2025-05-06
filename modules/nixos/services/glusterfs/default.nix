{ lib
, config
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.glusterfs;
in
{
  options.campground.services.glusterfs = with types; {
    enable = mkBoolOpt false "Enable GlusterFS server.";
    peers = mkOpt (listOf str) [ ] "List of GlusterFS peers.";
    volumes = mkOpt
      (listOf (submodule {
        options = {
          name = mkOpt str "Volume name";
          brickDirs = mkOpt (listOf str) [ ] "Bricks for this volume";
          replicaCount = mkOpt int 2 "Replica count";
          transport = mkOpt str "tcp" "Transport type (tcp or rdma)";
        };
      })) [ ] "List of GlusterFS volumes to create.";
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
      serviceConfig.Type = "oneshot";
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
