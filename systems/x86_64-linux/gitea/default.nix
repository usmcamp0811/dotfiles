{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.fmf; {
  # Set snowfallorg user name for home-manager
  home-manager.users.admin.snowfallorg.user.name = "admin";

  # MicroVMs don't use bootloaders - booted directly by QEMU
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  ############################################################
  # MicroVM configuration
  ############################################################
  microvm = {
    hypervisor = "qemu";

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/store";
      }
      {
        proto = "virtiofs";
        tag = "rw-store";
        source = "/persist/vm-stores/gitea/nix-store";
        mountPoint = "/nix/.rw-store";
      }
      {
        proto = "virtiofs";
        tag = "vault-agent";
        source = "/persist/system/var/lib/vault/gitea";
        mountPoint = "/var/lib/vault/gitea";
      }
      {
        proto = "virtiofs";
        tag = "gitea-data";
        source = "/persist/vm-data/gitea";
        mountPoint = "/var/lib/gitea";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-gitea";
        mac = "02:00:00:00:00:40";
      }
    ];

    vcpu = 4;
    mem = 4096;
    socket = "control.socket";
  };

  ############################################################
  # Deterministic NIC name
  ############################################################
  systemd.network.links."10-lan0" = {
    matchConfig.MACAddress = "02:00:00:00:00:40";
    linkConfig.Name = "lan0";
  };

  # Explicit network configuration for lan0
  systemd.network.networks."20-lan0" = {
    matchConfig.Name = "lan0";
    address = ["192.169.1.40/24"];
    gateway = ["192.169.1.1"];
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  ############################################################
  # Networking - static IP
  ############################################################
  networking.useNetworkd = true;
  networking.useDHCP = false;
  services.resolved.enable = false;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [22 3000 22022]; # SSH, Web UI, Git SSH

  networking.defaultGateway = {
    address = "192.169.1.1";
    interface = "lan0";
  };

  networking.nameservers = [
    "192.169.1.2" # AdGuard
    "1.1.1.1"
    "8.8.8.8"
  ];

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system configuration
  ############################################################
  fmf = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "Gitea Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/gitea/role-id";
          secret-id = "/var/lib/vault/gitea/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };

      gitea = {
        enable = true;
        appName = "AI Campground Gitea";

        settings = {
          server = {
            DOMAIN = "git.lan.aicampground.com";
            ROOT_URL = "https://git.lan.aicampground.com/";
            HTTP_PORT = 3000;
            SSH_PORT = 22022;
            DISABLE_SSH = false;
            START_SSH_SERVER = true;
          };

          service = {
            DISABLE_REGISTRATION = false;
            REQUIRE_SIGNIN_VIEW = false;
          };

          repository = {
            ROOT = "/var/lib/gitea/repositories";
          };

          database = {
            DB_TYPE = "sqlite3";
            PATH = "/var/lib/gitea/data/gitea.db";
          };

          session = {
            PROVIDER = "file";
          };

          log = {
            MODE = "file";
            LEVEL = "Info";
          };
        };
      };
    };
  };

  # Ensure gitea user has correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/gitea 0750 gitea gitea -"
    "d /var/lib/gitea/data 0750 gitea gitea -"
    "d /var/lib/gitea/repositories 0750 gitea gitea -"
  ];

  system.stateVersion = "23.05";
}
