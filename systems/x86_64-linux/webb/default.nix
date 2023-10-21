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
  # boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "igb" ];

  campground = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
    };

    # security = {
    #   acme = enabled;
    # };

    nfs = {
      campfs = enabled;
    };

    system = {
      boot = enabled;
      # vpn = enabled;
      zfs = {
        enable = true;
        hostId = "119db424";
        keyfile-url = "http://10.8.0.1:1234/zfs-keyfile";
      };
      # manage local passwd in vault
      passwds = enabled;
    };

    hardware.audio = {
    };

  };

  campground.user = {
    name = "abe";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    extraGroups = ["wheel"];
  };

  campground.services = {

    openssh = {
      authorizedKeys = [ "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler" ];
    };
    ldap-client = enabled;
    secret-service = enabled;
    tang = enabled;
    # k0sworker = enabled;
    # k0scontroller = enabled;
    ntp = enabled;
    zfs-key-server = {
      enable = true;
      tang-servers = [
       "http://daly:1234" 
       "http://lucas:1234" 
       "http://ermy:1234" 
      ];
      port = 8123;
    };
    # user-secrets = {
    #   enable = true;
    #   users = {
    #     mcamp =  {
    #       files = [
    #         "id_ed25519"
    #         "passwords"
    #       ];
    #     };
    #   };
    # };
    # homer = {
    #   enable = false;
    #   host = "webb";
    #
    #   package = pkgs.campground.homer-catppuccin.override { favicon = "light"; };
    #
    #   settings = {
    #     title = "Dashboard";
    #     subtitle = "Campground Home";
    #
    #     logo = pkgs.campground.homer-catppuccin.logos.light;
    #
    #     stylesheet = [
    #       pkgs.campground.homer-catppuccin.stylesheets.latte
    #       pkgs.campground.homer-catppuccin.stylesheets.frappe
    #     ];
    #
    #     footer = "";
    #
    #     connectivityCheck = true;
    #
    #     columns = "auto";
    #
    #     defaults = {
    #       layout = "list";
    #       colorTheme = "auto";
    #     };
    #
    #     services = [
    #       {
    #         name = "Administration";
    #         icon = "fas fa-shield-halved";
    #         items = [
    #           {
    #             name = "Vault";
    #             icon = "fas fa-lock";
    #             url = "http://vault.lan";
    #             target = "_blank";
    #           }
    #         ];
    #       }
    #     ];
    #   };
    #
    #   # settings-path = "/var/lib/homer/config.yml";
    # };

    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/webb/role-id";
          secret-id = "/var/lib/vault/webb/secret-id";
        };
      };
    };
  };
  # services.nginx = {
  #   enable = true;
  #   recommendedProxySettings = true;
  #
  #   virtualHosts =
  #     # TODO: get certs from certManager 
  #     # let
  #     #   shared-config = {
  #     #     extra-config = {
  #     #       forceSSL = true;
  #     #
  #     #       sslCertificate = "${config.security.acme.certs."daly.campground.lan".directory}/fullchain.pem";
  #     #       sslCertificateKey = "${config.security.acme.certs."daly.campground.lan".directory}/key.pem";
  #     #     };
  #     #   };
  #     # in
  #     {
  #       "vault.lan" = network.create-proxy
  #         ((network.get-address-parts config.services.vault.address));
  #           # // shared-config);
  #     };
  # };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

