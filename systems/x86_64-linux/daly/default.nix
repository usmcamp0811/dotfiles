{ pkgs, config, lib, nixos-hardware, nixosModules, agenix, ... }:

with lib;
with lib.campground;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in
{
  imports = [ 
    ./hardware.nix
  ];
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker"];
      uid = 10000;
    };
    suites.desktop.enable = mkForce false;
    archetypes = {
      laptop = enabled;
      server = {
        enable = true;
        k8s = true;
        role = "worker";
        hostId = "65c8b2d7";
      };
    };
    # security = {
    #   acme = enabled;
    # };
    nfs.client = {
      enable = true;
    };

    services = {
      keepalived = {
        enable = true;
        instances = {
            pub-campground = {
              interface = "enp3s0f1";
              ips = [ "10.8.0.69" ];  # Multiple IPs for instance1
              state = "MASTER";
              priority = 50;
              virtualRouterId = 51;
            };
          };
      };
      # attic-watch-store = enabled;
      ldap-server = enabled;
      # k0s = {
      #   enable = true;
      #   package = pkgs.campground.k0s; 
      #   role = "controller"; # Options: "controller", "worker", "controller+worker", "single"
      #   apiAddress = "10.8.0.1";
      #   # apiSans = [ "daly" "ermy" "campnet" ];
      #   apiSans = [ "10.8.0.1" ];
      #   clusterName = "campground";
      #   isLeader = false; # Set this to true on the initial controller node
      #   dataDir = "/var/lib/k0s";
      # };
      borgbackup = {
        enable = true;
        jobs = {
          "campground" = {
            paths = [ 
              "/persist" 
            ];
            repo = "mcamp@reckless:/mnt/backups/daly";
            startAt = "daily";
          };
          "daly_rsync" = {
            paths = [ 
              "/persist" 
            ];
            repo = "de3288@de3288.rsync.net:/data2/home/de3288/backups/daly";
            startAt = "daily";
          };
        };
      };
      searx = {
        enable = true;
        port = 8181;
      };
      zfs-key-server = {
        enable = true;
        tang-servers = [
         "http://webb:1234" 
         "http://chesty:1234" 
         "http://lucas:1234" 
         "http://ermy:1234" 
         "http://reckless:1234"
        ];
        port = 8123;
      };
      user-secrets = {
        enable = true;
        users = {
          mcamp =  {
            files = [
              "id_ed25519"
              "passwords"
            ];
          };
        };
      };
      homer = {
        enable = true;
        host = "daly";

        package = pkgs.campground.homer-catppuccin.override { favicon = "light"; };

        settings = {
          title = "Dashboard";
          subtitle = "Campground Home";

          logo = pkgs.campground.homer-catppuccin.logos.light;

          stylesheet = [
            pkgs.campground.homer-catppuccin.stylesheets.latte
            pkgs.campground.homer-catppuccin.stylesheets.frappe
          ];

          footer = "";

          connectivityCheck = true;

          columns = "auto";

          defaults = {
            layout = "list";
            colorTheme = "auto";
          };

          services = [
            {
              name = "Administration";
              icon = "fas fa-shield-halved";
              items = [
                {
                  name = "Vault";
                  icon = "fas fa-lock";
                  url = "http://vault.lan";
                  target = "_blank";
                }
              ];
            }
          ];
        };
      };

      vault = {
        enable = true;
        ui = true;
        storage = {
          backend = "file";
          path = "/persist/vault";
        };
        
        policies =
          builtins.foldl'
            (policies: file: policies // {
              "${snowfall.path.get-file-name-without-extension file}" = file;
            })
            { }
            (builtins.filter (snowfall.path.has-file-extension "hcl")
              (builtins.map
                (path:
                  ./vault/policies +
                  "/${builtins.baseNameOf (builtins.unsafeDiscardStringContext path)}"
                )
                (snowfall.fs.get-files ./vault/policies)));
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "http://vault.lan";
            role-id = "/var/lib/vault/daly/role-id";
            secret-id = "/var/lib/vault/daly/secret-id";
          };
        };
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "vault.lan" = network.create-proxy
        ((network.get-address-parts config.services.vault.address));
    };
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

