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

  # Use campground modules for configuration
  campground = {
    cli.aliases.root = enabled;

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

    ############################################################
    # Router configuration (single, consolidated)
    ############################################################
    router = {
      enable = true;

      # WAN: upstream network
      wan = {
        interface = "enp1s0";
        dhcp = true;
      };

      # LAN: bridge + gateway
      lan = {
        interfaces = ["enp2s0" "enp3s0" "enp4s0"];
        gateway = "192.169.1.1";
        prefixLength = 24;
      };

      # DHCP server for LAN clients
      dhcp = {
        enable = true;
        rangeStart = "192.169.1.50";
        rangeEnd = "192.169.1.200";
        leaseTime = "12h";
      };

      dns = {
        enable = true;
        forwarders = ["1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];
      };
      # Router security hardening
      security = {
        enable = true;
        enableSSH = true;
        sshPort = 22;
        fail2ban = {
          enable = true;
          maxRetry = 3;
          banTime = 3600;
        };
      };
    };

    # User configuration
    user = {
      name = "admin";
      fullName = "System Administrator";
      email = "admin@aicampground.com";
      extraGroups = [];
      uid = 1000;
      # initialPassword = null; # Don't use initialPassword when using hashedPasswordFile
      # hashedPasswordFile = "/persist/system/users/admin";
    };
  };

  # Disable conflicting DNS services - dnsmasq handles both DHCP and DNS
  # services.unbound.enable = lib.mkForce false;
  # services.resolved.enable = lib.mkForce false;

  # Static DHCP leases for MicroVMs (via dnsmasq)
  services.dnsmasq.settings.dhcp-host = [
    "02:00:00:00:00:10,192.169.1.10,vault"
    "02:00:00:00:00:11,192.169.1.11,websites"
    "02:00:00:00:00:20,192.169.1.20,pub-traefik"
    "02:00:00:00:00:21,192.169.1.21,lan-traefik"
  ];

  ############################################################
  # MicroVM host configuration
  ############################################################
  microvm.host = {
    enable = true;
    useNotifySockets = true;
  };

  microvm.vms = {
    vault = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    websites = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    pub-traefik = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    lan-traefik = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
  };

  ############################################################
  # Networking
  ############################################################
  networking.useNetworkd = true;

  # Add MicroVM TAP interfaces to the LAN bridge (br-lan)
  systemd.network.networks."30-lan-vm-taps" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  system.stateVersion = "23.05";
}
