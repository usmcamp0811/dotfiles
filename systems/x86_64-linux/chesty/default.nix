{ pkgs, config, lib, nixos-hardware, nixosModules, ... }:

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
  imports = [ ./hardware.nix ];

  campground = {
    archetypes.workstation = enabled;
    # tools.icehouse = enabled;
    nfs.campfs = enabled;

    system = {
      boot = enabled;
      zfs = {
        enable = true;
        hostId = "13ec383b";
        keyfile-url = "http://10.8.0.1:1234/zfs-keyfile";
      };
      passwds = enabled;
    };

    hardware = {
      nvidia = enabled;
    };

    user = {
      name = "abe";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel"];
    };

    services = {
      # TODO: configure searx
      # searx = {
      #   enable = true;
      # };
      hydra = enabled;
      jellyfin = enabled;

      openssh = { 
        authorizedKeys = [ 
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
        ];
      };
      ldap-client = enabled;
      tang = enabled;
      k0sworker = enabled;
      ntp = enabled;
      docker = enabled;
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [ 
          "http://daly:1234" 
          # "http://mattis:1234" 
          "http://lucas:1234" 
          "http://ermy:1234" 
          "http://webb:1234" 
          "http://reckless:1234"
        ];
      };

      user-secrets = {
        enable = true;
        users.mcamp = { 
          files = [ 
            "id_ed25519" 
            "passwords" 
          ]; 
        };
      };

      vault-agent = {
        enable = true;
        settings = { 
          vault = { 
            address = "https://vault.lan.aicampground.com"; 
            # address = "http://vault.lan/";
            role-id = "/var/lib/vault/chesty/role-id"; 
            secret-id = "/var/lib/vault/chesty/secret-id"; 
          }; 
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
