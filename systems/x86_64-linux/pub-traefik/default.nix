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
    writableStoreOverlay = "/nix/.rw-store";

    # Share the host's Nix store to save disk space
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
        source = "/var/lib/microvm/pub-traefik/nix-store";
        mountPoint = "/nix/.rw-store";
      }
      {
        proto = "virtiofs";
        tag = "vault-agent";
        source = "/persist/system/var/lib/vault/pub-traefik"; # Share actual files, not symlinks
        mountPoint = "/var/lib/vault/pub-traefik";
      }
    ];

    # Networking - TAP interface bridged to host network
    interfaces = [
      {
        type = "tap";
        id = "vm-traefik-pub";
        mac = "02:00:00:00:00:20"; # Static MAC for consistent DHCP
      }
    ];

    # Resources
    vcpu = 2;
    mem = 2047; # ~2GB RAM (avoid exactly 2048 due to QEMU bug)

    # Boot configuration
    socket = "control.socket";

    # Volumes for persistent data
    volumes = [
      {
        image = "traefik-public-data.img";
        mountPoint = "/var/lib/traefik";
        size = 5120; # 5GB for traefik data (logs, acme certs, etc.)
      }
    ];
  };

  networking.interfaces.eth0.useDHCP = true;

  # With writableStoreOverlay, the VM runs its own nix-daemon
  # No need to connect to host daemon

  # Disable nix store optimization - incompatible with writableStoreOverlay
  nix.optimise.automatic = false;
  nix.settings.auto-optimise-store = false;

  # Basic system configuration
  campground = {
    suites = {
      common = enabled;
      public-hosting = {
        enable = true;
        interface = "eth0";
        pub-ip = "10.8.0.42";
      };
    };

    user = {
      name = "admin";
      fullName = "Traefik Public Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/pub-traefik/role-id";
            secret-id = "/var/lib/vault/pub-traefik/secret-id";
          };
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

  system.stateVersion = "23.05";
}
