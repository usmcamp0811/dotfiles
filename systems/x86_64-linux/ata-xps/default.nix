{ pkgs, lib, nixos-hardware, nixosModules, agenix, ... }:

with lib;
with lib.internal;
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
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
    };

    system = {
      boot = enabled;
    };

    hardware.audio = {
    };

  };

  campground.home.extraOptions = {
  };

  campground.user = {
    name = "mcamp";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };

  campground.services = {
    secret-service = enabled;
    vault-agent = {
      enable = true;
      services = {
        "secret-service" = {
          settings = {
            vault.address = "https://vault.lan.aicampground.com";
            auto_auth = {
              method = [{
                type = "approle";
                config = {
                  role_id_file_path = "/var/lib/vault/secret-service/role-id";
                  secret_id_file_path = "/var/lib/vault/secret-service/secret-id";
                  remove_secret_id_file_after_reading = false;
                };
              }];
            };
          };
          # secrets.environment.templates = {
          #   secret-service-env = {
          #     text = ''
          #       {{ with secret "secret/campground" }}
          #       YANKEE_WHITE="{{ .Data.value }}"
          #       {{ end }}
          #     '';
          #   };
          # };
          secrets = {
            file = {
              files = {
                my-secret-file = {
                  text = ''
                    {{ with secret "secret/campground" }}
                    value="{{ .Data.value }}"
                    {{ end }}
                  '';
                  permissions = "0400";
                  change-action = "restart";
                  path = {
                    readOnly = true;
                    default = "/secret-file";
                  };
                };
              };
            };
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

