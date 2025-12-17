{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.campground; {
  home-manager.users.admin.snowfallorg.user.name = "admin";

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  ############################################################
  # MicroVM
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
  # Networking (static, simple, no firewall)
  ############################################################
  networking.useNetworkd = true;
  networking.useDHCP = false;
  services.resolved.enable = false;
  networking.firewall.enable = false;

  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "192.168.1.30";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = {
    address = "192.168.1.1";
    interface = "eth0";
  };

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system
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

    services.vault-agent = {
      enable = true;
      settings.vault = {
        address = "https://vault.lan.aicampground.com";
        role-id = "/var/lib/vault/adguard/role-id";
        secret-id = "/var/lib/vault/adguard/secret-id";
      };
    };

    services.openssh.enable = true;
  };

  ############################################################
  # AdGuard Home (DNS + DHCP)
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
          "8.8.8.8"
        ];
      };

      # 🚨 KEY FIX: no interface_name
      dhcp = {
        enabled = true;

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

  ############################################################
  # AdGuard user (persistent volume safe)
  ############################################################
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
