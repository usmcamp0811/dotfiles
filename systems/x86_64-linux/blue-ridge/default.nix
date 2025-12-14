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
        # Based on your ip a screenshot, enp4s0 is the active LAN port.
        # Keep only enp4s0 here unless you *know* enp2s0/enp3s0 are cabled.
        interfaces = ["enp4s0"];
        gateway = "192.168.1.1";
        prefixLength = 24;
      };

      # DHCP server for LAN clients (Butler)
      dhcp = {
        enable = true;
        rangeStart = "192.168.1.50";
        rangeEnd = "192.168.1.200";
        leaseTime = "12h";

        # If your campground.router module supports static leases, keep them.
        # If it expects different field names, adjust here to match your module.
        staticLeases = [
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

      dns = {
        # Keep your forwarders
        forwarders = ["1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];

        # If your module supports it, keep it. Otherwise remove.
        enableDNSSEC = true;
      };

      # Keep disabled unless you’ve built v6 in your module end-to-end
      enableIPv6 = false;

      firewall = {
        allowPing = true;
        extraRules = "";
      };

      # Router security hardening (unchanged)
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
      initialPassword = null; # Don't use initialPassword when using hashedPasswordFile
      hashedPasswordFile = "/users/admin";
    };
  };

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
