{ pkgs, lib, nixos-hardware, nixosModules, agenix, config, ... }:

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
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    archetypes = {
      workstation = enabled;
    };

    desktop.qtile = {
      enable = true;
      gdm = true;
    };
    
    apps = {
      emacs = {
        enable = true;
      };
    };

    system = {
      boot = enabled;
      # TODO: is there anything I can do to clean this up a little.. seems a little verbose
      # wifi = {
      #   enable = true;
      #   vault-path = "boterfhome_v1/wifi";
      #   networks = {
      #     boterf24 = {
      #       ssid = "Boterf-2.4G";
      #     };
      #     boterf5 = {
      #       ssid = "Boterf-5G";
      #     };
      #   };
      # };
      # vpn = {
      #   enable = false;
      #   networks = {
      #     CampNet = {
      #       key = "ata_xps";
      #     };
      #   };
      # };
    };

    hardware.audio = {
    };

  };

  campground.home.extraOptions = {
      home.shellAliases = {
      la = "lsd -lah";
      update = "sudo nixos-rebuild switch";
    };
  };

  campground.user = {
    name = "mboterf";
    fullName = "Michael Boterf";
    email = "michaelboterf@gmail.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };
  campground.tools = {
    git = {
      enable = true;
      userName = "BruceBoterf";
      userEmail = "mboterf@ata-llc.com";
    };
  };

  campground.services = {
    ldap-client = disabled;
    secret-service = disabled;
    cac = {
      enable = true;
    };
    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "http://10.2.0.196:8200";
          role-id = "/var/lib/vault/ata-xps-mboterf/role_id";
          secret-id = "/var/lib/vault/ata-xps-mboterf/secret_id";
       };
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
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts =
      # TODO: get certs from certManager 
      # let
      #   shared-config = {
      #     extra-config = {
      #       forceSSL = true;
      #
      #       sslCertificate = "${config.security.acme.certs."daly.campground.lan".directory}/fullchain.pem";
      #       sslCertificateKey = "${config.security.acme.certs."daly.campground.lan".directory}/key.pem";
      #     };
      #   };
      # in
      {
        "vault.lan" = network.create-proxy
          ((network.get-address-parts config.services.vault.address));
            # // shared-config);
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
