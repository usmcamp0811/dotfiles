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
    user = {
      name = "abe";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel"];
    };

    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        worker = true;
        hostId = "930864f0";
      };
    };
    nfs.client.enable = true;

    services = {
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [ 
          "http://daly:1234" 
          # "http://mattis:1234" 
          "http://chesty:1234" 
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
            role-id = "/var/lib/vault/lucas/role-id"; 
            secret-id = "/var/lib/vault/lucas/secret-id"; 
          }; 
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
