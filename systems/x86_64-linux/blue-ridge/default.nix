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

    # Router configuration - MicroVMs on LAN, not WAN
    router = {
      enable = true;

      wan = {
        interface = "enp1s0";
        dhcp = true;
      };

      lan = {
        interfaces = ["enp2s0" "enp3s0" "enp4s0"];
        subnet = "192.168.1.0/24";
        gateway = "192.168.1.1";
      };

      dns = {
        forwarders = ["1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];
        enableDNSSEC = true;
      };

      enableIPv6 = false;

      firewall = {
        allowPing = false;
        extraRules = "";
      };
    };

    # DHCP server for LAN
    router.dhcp = {
      enable = true;
      poolStart = "192.168.1.100";
      poolEnd = "192.168.1.200";
      leaseTime = 86400; # 24 hours

      staticLeases = [
        # MicroVMs get static IPs for consistency
        {
          mac = "02:00:00:00:00:10";
          ip = "192.168.1.10";
          hostname = "vault";
        }
        {
          mac = "02:00:00:00:00:11";
          ip = "192.168.1.11";
          hostname = "websites";
        }
        {
          mac = "02:00:00:00:00:20";
          ip = "192.168.1.20";
          hostname = "pub-traefik";
        }
        {
          mac = "02:00:00:00:00:21";
          ip = "192.168.1.21";
          hostname = "lan-traefik";
        }
      ];
    };

    # Router security hardening
    router.security = {
      enable = true;
      enableSSH = true;
      sshPort = 22;
      fail2ban = {
        enable = true;
        maxRetry = 3;
        banTime = 3600;
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
      initialPassword = null; # Don't use initialPassword when using hashedPasswordFile
      hashedPasswordFile = "/users/admin";
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

  # Network configuration is handled by campground.router module
  # The router module will:
  # - Configure WAN on enp1s0 (DHCP from ISP)
  # - Create br-lan bridge with enp2s0, enp3s0, enp4s0
  # - Run DHCP server for LAN (192.168.1.0/24)
  # - Run Unbound DNS resolver
  # - Configure nftables firewall with NAT
  networking.useNetworkd = true;

  # Add MicroVM TAP interfaces to the LAN bridge
  systemd.network.networks."30-lan-vm-taps" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  # State version
  system.stateVersion = "23.05";
}
