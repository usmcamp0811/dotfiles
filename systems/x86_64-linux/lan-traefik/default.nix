{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.campground; {
  # MicroVM configuration
  microvm = {
    # Use microvm as the hypervisor (lightweight, fast boot)
    hypervisor = "qemu";

    # Share the host's Nix store to save disk space
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Networking - TAP interface bridged to host network
    interfaces = [
      {
        type = "tap";
        id = "vm-traefik-lan";
        mac = "02:00:00:00:00:21"; # Static MAC for consistent DHCP
      }
    ];

    # Resources
    vcpu = 2;
    mem = 2048; # 2GB RAM - adjust based on workload

    # Boot configuration
    socket = "control.socket";

    # Volumes for persistent data
    volumes = [
      {
        image = "traefik-lan-data.img";
        mountPoint = "/var/lib/traefik";
        size = 5120; # 5GB for traefik data (logs, acme certs, etc.)
      }
    ];
  };

  networking.interfaces.eth0.useDHCP = true;
  # Basic system configuration
  campground = {
    suites = {
      common = enabled;
      lan-hosting = {
        enable = true;
        interface = "eth0";
        lan-ip = "10.8.0.69";
      };
    };

    user = {
      name = "admin";
      fullName = "Traefik LAN Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };
  };

  system.stateVersion = "23.05";
}
