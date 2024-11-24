{ pkgs, config, lib, inputs, ... }:
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
  # cause ASUS sucks and the ethernet port dies
  boot.kernelParams = [ "pcie_port_pm=off" "pcie_aspm.policy=performance" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
  #   version = "555.42.02";
  #   sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
  #   sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   persistencedSha256 = lib.fakeSha256;
  # };
  # boot.kernelPackages = mkDefault pkgs.linuxPackages_6_8_10;
  systemd.services.proton-socat-smtp = {
    description = "Socat Service for Proton Bridge SMTP Port Forwarding";
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.socat}/bin/socat TCP4-LISTEN:587,fork TCP4:127.0.0.1:1025";
      Restart = "always";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.proton-socat-imap = {
    description = "Socat Service for Proton Bridge IMAP Port Forwarding";
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.socat}/bin/socat TCP4-LISTEN:143,fork TCP4:127.0.0.1:1143";
      Restart = "always";
    };
    wantedBy = [ "multi-user.target" ];
  };

  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };

    security.gpg = enabled;
    suites = {
      public-hosting = {
        enable = true;
        interface = "eno1";
        log-to-kafka = true;
      };
    };
    desktop.addons.rkvm = {
      enableServer = true;
      # enableClient = true;
      # address = "ata-nuc:5258";
    };

    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        hostId = "13ec383b";
      };
    };

    suites = { development = enabled; };

    nix = {
      extra-substituters = {
        "https://nix-gaming.cachix.org" = {
          key =
            "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
        };
      };
    };

    apps = { steam = enabled; };

    # tools = { nix-doc = enabled; };

    nfs.client = { enable = true; };

    hardware = {
      ckb-next = enabled;
      ups.cp1500 = { enable = true; };
      nvidia = {
        enable = true;
        # driverType = "stable";
        # driverType = "production";
        # # driverType = "custom";
        # customDriverPackage =
        #   config.boot.kernelPackages.nvidiaPackages.beta.overrideAttrs {
        #     version = "550.78";
        #     # the new driver
        #     src = pkgs.fetchurl {
        #       url =
        #         "https://us.download.nvidia.com/XFree86/Linux-x86_64/550.78/NVIDIA-Linux-x86_64-550.78.run";
        #       sha256 = "sha256-NAcENFJ+ydV1SD5/EcoHjkZ+c/be/FQ2bs+9z+Sjv3M=";
        #     };
        #   };
        # customDriverPackage =
        #   config.boot.kernelPackages.nvidiaPackages.beta.overrideAttrs {
        #     version = "550.40.07";
        #     # the new driver
        #     src = pkgs.fetchurl {
        #       url =
        #         "https://download.nvidia.com/XFree86/Linux-x86_64/550.40.07/NVIDIA-Linux-x86_64-550.40.07.run";
        #       sha256 = "sha256-KYk2xye37v7ZW7h+uNJM/u8fNf7KyGTZjiaU03dJpK0=";
        #     };
        #   };
      };
      bluetooth = enabled;
    };

    services = {
      cac = enabled;
      campground-blog = enabled;
      qdrant = {
        enable = true;
        settings.service.host = "0.0.0.0";
      };
      open-webui = enabled;
      ollama = {
        enable = true;
        # host = "0.0.0.0";

      };
      # local-ai = enabled;
      file-share = enabled;
      ldap-client = { enable = mkForce false; };
      attic-watch-store = enabled;
      gitlab-runner = enabled;
      netbird = enabled;
      hadoop = {
        enable = true;
        yarnSite = { "yarn.nodemanager.hostname" = "reckless"; };
        hdfs = {
          datanode.enable = true;
          datanode.restartIfChanged = true;
          datanode.openFirewall = true;
          datanode.extraFlags = [ ];
          datanode.extraEnv = { };
          datanode.dataDirs = [ ];

          journalnode.enable = true;
          journalnode.restartIfChanged = true;
          journalnode.openFirewall = true;
          journalnode.extraFlags = [ ];
          journalnode.extraEnv = { };

          httpfs.enable = true;
        };
        yarn = {
          nodemanager.enable = true;
          nodemanager.useCGroups = false;
          nodemanager.restartIfChanged = true;
          nodemanager.resource.memoryMB = null;
          nodemanager.resource.maximumAllocationVCores = null;
          nodemanager.resource.maximumAllocationMB = null;
          nodemanager.resource.cpuVCores = null;
          nodemanager.openFirewall = true;
          nodemanager.localDir = null;
          nodemanager.extraFlags = [ ];
          nodemanager.extraEnv = { };
          nodemanager.addBinBash = true;
        };
      };
      attic = {
        enable = true;
        settings = {
          listen = "[::]:8082";
          database = {
            url = "postgres://atticd@localhost/atticd?host=/run/postgresql/";
          };
          storage = {
            type = "local";
            path = "/var/lib/atticd";
          };
          chunking = {
            "nar-size-threshold" =
              65536; # chunk files that are 64 KiB or larger
            "min-size" = 16384; # 16 KiB
            "avg-size" = 65536; # 64 KiB
            "max-size" = 262144; # 256 KiB
          };
          compression = { type = "zstd"; };
          garbage-collection = { interval = "144 hours"; };
        };
      };

      postgresql = {
        enable = true;
        enableTCPIP = true;
        databases = [{
          name = "atticd";
          user = "atticd";
        }];
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = [
          "local all root trust"
          "local all postgres peer"
          "local atticd atticd trust"
          # "host  campgroundai  campgroundai  0.0.0.0/0 md5"
          "host  all  all  0.0.0.0/0  reject"
          "host  all  all  ::0/0  reject"

        ];
      };
      nix-snapshotter = enabled;
      flakeforge = enabled;
      zfs-key-server = {
        enable = true;
        interface = "eno1";
        tang-servers = [
          "http://webb:1234"
          "http://lucas:1234"
          "http://chesty:1234"
          # "http://mattis:1234"
          "http://daly:1234"
        ];
      };

      user-secrets = {
        enable = true;
        users = {
          mcamp = { files = [ "id_ed25519" "passwords" "kubeconfig" ]; };
        };
      };

      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/reckless/role-id";
            secret-id = "/var/lib/vault/reckless/secret-id";
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
