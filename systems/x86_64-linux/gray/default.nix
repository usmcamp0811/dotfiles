{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in {
  imports = [./hardware.nix];
  programs.adb.enable = true;
  boot.kernelPackages = pkgs.linuxPackages;

  services.tlp = {enable = mkForce false;};
  fmf = {
    # rmf.example-flask-app = {
    #   # enable = true;
    #   settings = {
    #     port = 8081;
    #   };
    #   controls = {
    #     CM-2 = {
    #       enabled = false;
    #       justification = [ "dev box, manual baseline config accepted" ];
    #     };
    #   };
    # };

    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker" "adbusers" "kvm"];
      uid = 10000;
    };

    apps = {steam = enabled;};

    archetypes = {
      laptop = enabled;
      workstation = enabled;
    };

    nfs.client = {enable = true;};

    hardware = {bluetooth = enabled;};

    services = {
      ldap-client = {enable = mkForce false;};
      netbird.client = enabled;
      user-secrets = {
        enable = true;
        users = {
          mcamp = {files = ["id_ed25519" "passwords" "kubeconfig"];};
        };
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/gray/role-id";
            secret-id = "/var/lib/vault/gray/secret-id";
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
