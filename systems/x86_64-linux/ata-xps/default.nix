{ pkgs, lib, nixos-hardware, nixosModules, agenix, ... }:

with lib;
with lib.internal;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
    # ... any other common settings ...
  };
  mysecrets = builtins.fetchGit {
    url = "https://gitlab.com/usmcamp0811/campground-secrets.git";
    ref = "master"; 
    rev = "57228b7bbd48b88a6660f6d2a9540be893e76976"; 
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
      # agenix = enabled;

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
    vault-agent = {
      enable = true;

      settings = {
        vault.address = "https://vault.lan.campground.com";
        auto_auth = {
          method = [{
            type = "approle";

            config = {
              role_id_file_path = "/var/lib/vault/role-id";
              secret_id_file_path = "/var/lib/vault/secret-id";

              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };

      services = {
          "my-service" = {
            settings = {
              vault.address = "https://vault.quartz.hamho.me";

              auto_auth = {
                method = [{
                  type = "approle";

                  config = {
                    role_id_file_path = "/var/lib/vault/role-id";
                    secret_id_file_path = "/var/lib/vault/secret-id";

                    remove_secret_id_file_after_reading = false;
                  };
                }];
              };
            };

            secrets.file.files = {
              my-secret = {
                text = ''
                  {{ with secret "secret/campground" }}
                  {{ .Data.value }}
                  {{ end }}
                '';
                path = "/secret-tst";
                permissions = "0400";
              };
            };
          };
        };
      };
  };

  # age.secrets."test" = {
  #   # wether secrets are symlinked to age.secrets.<name>.path
  #   symlink = true;
  #   # target path for decrypted file
  #   path = "/etc/some-secret-file";
  #   # encrypted file path
  #   file =  "${mysecrets}/test.age";  # refer to ./xxx.age located in `mysecrets` repo
  #   mode = "0400";
  #   owner = "root";
  #   group = "root";
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

