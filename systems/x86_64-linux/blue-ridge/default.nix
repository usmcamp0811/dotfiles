{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.campground; {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./impermanence.nix
  ];

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # users.mutableUsers = true;
  # Use campground modules for configuration
  campground = {
    suites = {
      common = enabled;
      observability = enabled;
    };
    system = {
      passwds = enabled;
    };
    services = {
      ntp = enabled;
      tang = enabled;
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/blue-ridge/role-id";
            secret-id = "/var/lib/vault/blue-ridge/secret-id";
          };
        };
      };
      openssh = {
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };

    # User configuration
    user = {
      name = "admin";
      fullName = "System Administrator";
      email = "admin@aicampground.com";
      extraGroups = [];
      uid = 1000;
      # generate with: nix-shell --run 'mkpasswd -m SHA-512 -s' -p mkpasswd
      passwordFile = "/nix/persist/users/admin";
    };
  };

  # MicroVM host configuration
  microvm.host = {
    enable = true;
    # Use the declarative runner for easier management
    useNotifySockets = true;
  };

  # Declare VMs to run on this host
  microvm.vms = {
    vault = {
      # Reference the vault system configuration from this flake
      # microvm.nix will look for nixosConfigurations.vault
      flake = inputs.self;
      # Auto-start the VM when blue-ridge boots
      autostart = true;
      restartIfChanged = true;
      # Update flake reference (optional - allows VM updates without host rebuild)
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    websites = {
      # Reference the vault system configuration from this flake
      # microvm.nix will look for nixosConfigurations.vault
      flake = inputs.self;
      # Auto-start the VM when blue-ridge boots
      autostart = true;
      restartIfChanged = true;
      # Update flake reference (optional - allows VM updates without host rebuild)
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    pub-traefik = {
      # Reference the vault system configuration from this flake
      # microvm.nix will look for nixosConfigurations.vault
      flake = inputs.self;
      # Auto-start the VM when blue-ridge boots
      autostart = true;
      restartIfChanged = true;
      # Update flake reference (optional - allows VM updates without host rebuild)
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    lan-traefik = {
      # Reference the vault system configuration from this flake
      # microvm.nix will look for nixosConfigurations.vault
      flake = inputs.self;
      # Auto-start the VM when blue-ridge boots
      autostart = true;
      restartIfChanged = true;
      # Update flake reference (optional - allows VM updates without host rebuild)
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
  };

  # Create directories for VM nix stores
  systemd.tmpfiles.rules = [
    "d /var/lib/microvms/vault/nix-store 0755 root root -"
    "d /var/lib/microvms/websites/nix-store 0755 root root -"
    "d /var/lib/microvms/pub-traefik/nix-store 0755 root root -"
    "d /var/lib/microvms/lan-traefik/nix-store 0755 root root -"
  ];

  # Network configuration - Use systemd-networkd for bridge (microvm.nix recommended setup)
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;

    # Bridge device
    netdevs."br0" = {
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
    };

    # Physical interface + all VM TAP interfaces (vm-*) -> bridge
    networks."10-lan" = {
      matchConfig.Name = ["enp2s0" "vm-*"];
      networkConfig = {
        Bridge = "br0";
      };
    };

    # Bridge network - gets IP via DHCP
    networks."10-lan-bridge" = {
      matchConfig.Name = "br0";
      networkConfig = {
        DHCP = "yes";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # State version
  system.stateVersion = "23.05";
}
