{ lib, ... }:
with lib;
with lib.campground;
# let
#   newUser = name: {
#     isNormalUser = true;
#     createHome = true;
#     home = "/home/${name}";
#     shell = pkgs.zsh;
#   };
# in 
{
  imports = [ ./hardware.nix ];
  campground = {
    nfs.client.enable = true;
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" ];
      GroupsIds = {
        users = 10000;
        k8s = 999;
        paperless = 317;
      };
      uid = 10000;
    };

    suites = {
      lan-hosting = {
        enable = true;
        interface = "enp7s0";
      };
      kubernetes = {
        enable = true;
        role = "worker";
        interface = "enp7s0";
      };
      kafka = {
        # enable = true;
        interface = "enp7s0";
        zookeeper-id = 1;
        servers = ''
          server.1=127.0.0.1:2888:3888
          server.2=webb:2888:3888
          server.3=daly:2888:3888
          server.4=lucas:2888:3888
        '';
      };
    };
    archetypes = {
      server = {
        enable = true;
        hostId = "13ec383b";
      };
    };
    hardware = { nvidia = enabled; };
    services = {
      ldap-client = { enable = mkForce false; };
      attic-watch-store = enabled;
      # netbird.client.enable = true;

      hadoop = {
        # enable = true;
        # yarnSite = {
        #   "yarn.nodemanager.hostname" = "chesty";
        #   "yarn.scheduler.capacity.root.queues" = "default";
        #   "yarn.scheduler.capacity.root.default.capacity" = "100";
        #
        # };
        # hdfs = {
        #   namenode.enable = true;
        #   namenode.restartIfChanged = true;
        #   namenode.openFirewall = true;
        #   namenode.extraFlags = [ ];
        #   namenode.extraEnv = { };
        #
        #   datanode.enable = true;
        #   datanode.restartIfChanged = true;
        #   datanode.openFirewall = true;
        #   datanode.extraFlags = [ ];
        #   datanode.extraEnv = { };
        #   datanode.dataDirs = [ ];
        #
        #   zkfc.enable = true;
        #   zkfc.restartIfChanged = true;
        #   zkfc.extraFlags = [ ];
        #   zkfc.extraEnv = { };
        #
        #   httpfs.enable = true;
        #   httpfs.tempPath = "/tmp/hadoop/httpfs";
        #   httpfs.restartIfChanged = true;
        #   httpfs.openFirewall = true;
        #   httpfs.extraFlags = [ ];
        #   httpfs.extraEnv = { };
        # };
        yarn = {
          resourcemanager.enable = true;
          resourcemanager.restartIfChanged = true;
          resourcemanager.openFirewall = true;
          resourcemanager.extraFlags = [ ];
          resourcemanager.extraEnv = { };

          nodemanager.enable = true;
          nodemanager.useCGroups = false;
          nodemanager.restartIfChanged = true;
          nodemanager.resource.memoryMB = null;
          nodemanager.resource.maximumAllocationVCores = null;
          nodemanager.resource.maximumAllocationMB = null;
          nodemanager.resource.cpuVCores = null;
          nodemanager.openFirewall = true;
          nodemanager.localDir = null;
          nodemanager.extraFlags = [ ];
          nodemanager.extraEnv = { };
          nodemanager.addBinBash = true;
        };
      };
      # hydra = enabled;
      jellyfin = enabled;
      campground-blog = enabled;
      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-chesty"
            retry_join {
              leader_api_addr = "http://ermy:8200"
            }
            retry_join {
              leader_api_addr = "http://daly:8200"
            }
            retry_join {
              leader_api_addr = "http://webb:8200"
            }
          '';
        };
        settings = ''
          cluster_addr = "http://chesty:8201" 
          api_addr = "http://chesty:8200"
        '';

        policies = builtins.foldl' (policies: file:
          policies // {
            "${snowfall.path.get-file-name-without-extension file}" = file;
          }) { } (builtins.filter (snowfall.path.has-file-extension "hcl")
            (builtins.map (path:
              ../daly/vault/policies + "/${
                builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
              }") (snowfall.fs.get-files ../daly/vault/policies)));
      };
      searx = {
        enable = true;
        port = 3249;
      };
      # keycloak = {
      #   enable = true;
      #   port = 43852;
      # };
      zfs-key-server = {
        enable = true;
        interface = "enp7s0";
        port = 8123;
        tang-servers = [
          "http://daly:1234"
          "http://lucas:1234"
          # "http://ermy:1234"
          "http://webb:1234"
          "http://reckless:1234"
        ];
      };
      user-secrets = {
        enable = true;
        users.mcamp = { files = [ "id_ed25519" "passwords" ]; };
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            # address = "http://lucas:8200";
            role-id = "/var/lib/vault/chesty/role-id";
            secret-id = "/var/lib/vault/chesty/secret-id";
          };
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
