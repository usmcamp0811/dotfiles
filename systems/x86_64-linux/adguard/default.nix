{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.campground; {
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
        source = "/persist/vm-stores/adguard/nix-store";
        mountPoint = "/nix/.rw-store";
      }
      {
        proto = "virtiofs";
        tag = "vault-agent";
        source = "/persist/system/var/lib/vault/adguard";
        mountPoint = "/var/lib/vault/adguard";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-adguard";
        mac = "02:00:00:00:00:30";
      }
    ];

    vcpu = 2;
    mem = 2047;
    socket = "control.socket";

    volumes = [
      {
        image = "adguard-data.img";
        mountPoint = "/var/lib/AdGuardHome";
        size = 5120;
      }
    ];
  };

  ############################################################
  # Deterministic NIC name (critical for AdGuard DHCP)
  ############################################################
  systemd.network.links."10-lan0" = {
    matchConfig.MACAddress = "02:00:00:00:00:30";
    linkConfig.Name = "lan0";
  };

  ############################################################
  # Networking - static IP (this VM is DHCP server)
  ############################################################
  networking.useNetworkd = true;
  networking.useDHCP = false;
  services.resolved.enable = false;

  # Avoid DHCP being blocked by guest firewall
  networking.firewall.enable = false;

  networking.interfaces.lan0.ipv4.addresses = [
    {
      address = "192.168.1.30";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = {
    address = "192.168.1.1";
    interface = "lan0";
  };

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "8.8.8.8"
    "8.8.4.4"
  ];

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system configuration
  ############################################################
  campground = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "AdGuard Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/adguard/role-id";
          secret-id = "/var/lib/vault/adguard/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };
  };

  ############################################################
  # AdGuard Home DNS + DHCP
  #
  # NOTE: AdGuard *does* care about interface_name for DHCP.
  # Binding to lan0 avoids all the eth0/ens3 naming flakiness.
  ############################################################
  services.adguardhome = {
    enable = true;
    mutableSettings = true;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      dns = {
        bind_hosts = ["0.0.0.0"];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
      };

      dhcp = {
        enabled = true;
        interface_name = "lan0";

        dhcpv4 = {
          gateway_ip = "192.168.1.1";
          subnet_mask = "255.255.255.0";
          range_start = "192.168.1.50";
          range_end = "192.168.1.200";
          lease_duration = 43200;
        };
      };
    };
  };

  # Persistent volume-safe service config
  systemd.services.adguardhome.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "adguardhome";
    Group = "adguardhome";
    StateDirectory = lib.mkForce "AdGuardHome";
  };

  users.users.adguardhome = {
    isSystemUser = true;
    group = "adguardhome";
    home = "/var/lib/AdGuardHome";
  };
  users.groups.adguardhome = {};

  system.stateVersion = "23.05";
}
