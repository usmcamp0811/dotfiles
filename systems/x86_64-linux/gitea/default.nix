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
    writableStoreOverlay = "/nix/.rw-store";

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
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
        domain = "git.lan.aicampground.com";
        port = 3000;
        httpPort = 8445;
        sshPort = 22022;
        databaseType = "sqlite3";
        repositoryRoot = "/var/lib/gitea/repositories";
        stateDir = "/var/lib/gitea";
        disableRegistration = false;
        enableLFS = true;
        enableActions = true;
      };
    };
  };

  system.stateVersion = "23.05";
}
