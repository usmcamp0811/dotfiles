{ lib
, config
, pkgs
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
      path = [ pkgs.glusterfs ];
      serviceConfig.Type = "oneshot";
      script =
        ''
          set -e

          for peer in ${lib.concatStringsSep " " cfg.peers}; do
            echo "Probing peer $peer..."
            i=1
            while [ "$i" -le 30 ]; do
              if ${pkgs.glusterfs}/bin/gluster peer probe "$peer" >/dev/null 2>&1; then
                echo "Peer $peer added"
                break
              fi
              echo "Waiting for peer $peer to become reachable... ($i/30)"
              i=$((i + 1))
              sleep 2
            done
          done
        ''
        + (lib.optionalString (cfg.volumes != [ ]) (lib.concatMapStringsSep "\n"
          (vol:
            let
              bricks = lib.concatMapStringsSep " " (dir: "${config.networking.hostName}:${dir}") vol.brickDirs;
            in
            ''
              missing=0
              for brick in ${bricks}; do
                host="''${brick%%:*}"
                path="''${brick#*:}"
                if [ "$host" = "${config.networking.hostName}" ]; then
                  if [ ! -d "$path" ]; then
                    echo "Missing local brick path: $path"
                    missing=1
                  fi
                fi
              done

              if [ "$missing" -eq 1 ]; then
                echo "One or more local brick paths missing; skipping volume ${vol.name}"
                exit 0
              fi

              if ! ${pkgs.glusterfs}/bin/gluster volume info ${vol.name} >/dev/null 2>&1; then
                ${pkgs.glusterfs}/bin/gluster volume create ${vol.name} \
                  replica ${toString vol.replicaCount} \
                  transport ${vol.transport} \
                  ${bricks} force
              fi

              if ! ${pkgs.glusterfs}/bin/gluster volume status ${vol.name} >/dev/null 2>&1; then
                ${pkgs.glusterfs}/bin/gluster volume start ${vol.name}
              fi
            '')
          cfg.volumes));
    };

    networking.firewall.allowedTCPPorts = [ 24007 24008 24009 49152 49153 ];
  };
}
