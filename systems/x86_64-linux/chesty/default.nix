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
    nfs.client.enable = true;
    user = {
      name = "abe";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel"];
    };
    archetypes = {
      server = {
        enable = true;
        worker = true;
        hostId = "13ec383b";
      };
    };
    hardware = {
      nvidia = enabled;
    };
    services = {
      hydra = enabled;
      jellyfin = enabled;
      searx = enabled;
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [ 
          "http://daly:1234" 
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
            role-id = "/var/lib/vault/chesty/role-id"; 
            secret-id = "/var/lib/vault/chesty/secret-id"; 
          }; 
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
