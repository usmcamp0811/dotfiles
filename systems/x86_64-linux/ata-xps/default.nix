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
    name = "abe";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };

  campground.services = {
    ldap-client = enabled;
    secret-service = enabled;
    vault-agent = {
      enable = true;
      services = {
        sssd = {
          settings = {
            vault.address = "https://vault.lan.aicampground.com";
            auto_auth = {
              method = [{
                type = "approle";
                config = {
                  role_id_file_path = "/var/lib/vault/sssd/role-id";
                  secret_id_file_path = "/var/lib/vault/sssd/secret-id";
                  remove_secret_id_file_after_reading = false;
                };
              }];
            };
          };
          secrets = {
            file = {
              files = {
                "ldap_ca.pem" = {
                  text = ''
                    {{ with secret "secret/campground/ldap" }}
                    {{ .Data.ldap_ca }}
                    {{ end }}
                  '';
                  permissions = "0400";
                  change-action = "restart";
                };
              };
            };
          };
        };
        "wifi-passwords" = {
          settings = {
            vault.address = "https://vault.lan.aicampground.com";
            auto_auth = {
              method = [{
                type = "approle";
                config = {
                  role_id_file_path = "/var/lib/vault/wifi/role-id";
                  secret_id_file_path = "/var/lib/vault/wifi/secret-id";
                  remove_secret_id_file_after_reading = false;
                };
              }];
            };
          };
          secrets = {
            file = {
              files = { 
                #TODO: Should this be a template? Or can this be done in a simpler way?
                "wifi-passwords" = {
                  text = ''
                    #!/bin/sh
                    SSID_SkyNet="SkyNet"
                    PASSWORD_SkyNet={{ with secret "secret/campground/wifi" }}{{ .Data.SkyNet }}{{ end }}
                    nmcli connection modify $SSID_SkyNet 802-11-wireless-security.psk $PASSWORD_SkyNet

                    SSID_SkyNet5="SkyNet5"
                    PASSWORD_SkyNet5={{ with secret "secret/campground/wifi" }}{{ .Data.SkyNet5 }}{{ end }}
                    nmcli connection modify $SSID_SkyNet5 802-11-wireless-security.psk $PASSWORD_SkyNet5
                  '';
                  permissions = "0400";
                  change-action = "restart";
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

