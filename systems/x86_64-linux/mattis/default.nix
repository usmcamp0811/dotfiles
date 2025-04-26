{ pkgs
, lib
, nixos-hardware
, nixosModules
, ...
}:
with lib;
with lib.campground; let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in
{
  imports = [ ./hardware.nix ];

  boot.initrd.availableKernelModules = [ "thunderbolt" "xhci_hcd" ];

  services.logind.lidSwitch = "ignore";
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };

    suites = {
      public-hosting = {
        enable = true;
        interface = "enp0s20f0u1";
      };
      # kubernetes = {
      #   enable = true;
      #   role = "worker";
      #   interface = "enp0s20f0u1";
      # };
    };

    archetypes = {
      laptop = enabled;
      server = {
        enable = true;
        hostId = "5ae58e7a";
      };
    };

    # nfs.client = {
    #   campfs = enabled;
    #   webb = enabled;
    #   chestyfs = enabled;
    # };

    services = {
      # ldap-client = enabled;
      label-studio = {
        enable = true;
        port = 19823;
      };

      matt-camp-website = enabled;
      postgresql = {
        enable = true;
        enableTCPIP = true;
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = [
          "local all root trust"
          "local all postgres peer"
          "local vaultwarden vaultwarden trust"
          "host  all  all  0.0.0.0/0  reject"
          "host  all  all  ::0/0  reject"
        ];
        databases = [
          {
            name = "vaultwarden";
            user = "vaultwarden";
          }
        ];
      };
      syncthing = enabled;
      tang = enabled;
      # zfs-key-server = {
      #   enable = true;
      #   port = 8123;
      #   interface = "enp0s20f0u1";
      #   tang-servers = [
      #     "http://webb:1234"
      #     # "http://daly:1234"
      #     "http://ermy:1234"
      #     "http://reckless:1234"
      #     "http://lucas:1234"
      #   ];
      # };
      user-secrets = {
        enable = true;
        users = { mcamp = { files = [ "id_ed25519" "passwords" ]; }; };
      };

      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-mattis"
            retry_join {
              leader_api_addr = "http://chesty:8200"
            }
            retry_join {
              leader_api_addr = "http://ermy:8200"
            }
            retry_join {
              leader_api_addr = "http://lucas:8200"
            }
            retry_join {
              leader_api_addr = "http://daly:8200"
            }
          '';
        };
        settings = ''
          cluster_addr = "http://mattis:8201"
          api_addr = "https://vault.lan.aicampground.com"
        '';

        policies =
          builtins.foldl'
            (policies: file:
              policies
              // {
                "${snowfall.path.get-file-name-without-extension file}" = file;
              })
            { }
            (builtins.filter (snowfall.path.has-file-extension "hcl")
              (builtins.map
                (path:
                  ../daly/vault/policies
                  + "/${
                  builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
                }")
                (snowfall.fs.get-files ../daly/vault/policies)));
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/mattis/role-id";
            secret-id = "/var/lib/vault/mattis/secret-id";
          };
        };
      };
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
