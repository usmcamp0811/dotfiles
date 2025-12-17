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

  ############################################################
  # Locale / Console
  ############################################################
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  ############################################################
  # Campground baseline
  ############################################################
  campground = {
    cli.aliases.root = enabled;

    suites = {
      common = enabled;
      observability = enabled;
    };

    system.passwds = enabled;

    services = {
      ntp = enabled;
      tang = enabled;

      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/blue-ridge/role-id";
          secret-id = "/var/lib/vault/blue-ridge/secret-id";
        };
      };

      openssh.authorizedKeys = [
        "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
      ];
    };

    ############################################################
    # Router (authoritative for WAN/LAN/NAT only)
    ############################################################
    router = {
      enable = true;

      # WAN
      wan = {
        interface = "enp1s0";
        dhcp = true;
      };

      # LAN (static; NEVER DHCP)
      lan = {
        interfaces = ["enp2s0" "enp3s0" "enp4s0"];
        gateway = "192.168.1.1";
        prefixLength = 24;
      };

      # DHCP/DNS intentionally disabled here
      # AdGuard microVM is authoritative
      dhcp.enable = false;
      dns.enable = false;

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

      portForwards = [
        {
          port = 443;
          destination = "192.168.1.20";
          protocol = "tcp";
          description = "HTTPS to pub-traefik";
        }
      ];
    };

    ############################################################
    # Admin user
    ############################################################
    user = {
      name = "admin";
      fullName = "System Administrator";
      email = "admin@aicampground.com";
      uid = 1000;
      extraGroups = [];
    };
  };

  ############################################################
  # Networking (host)
  ############################################################
  networking = {
    useNetworkd = true;

    # Router module owns firewall rules
    firewall.enable = lib.mkForce false;

    # Let the host itself resolve via AdGuard
    nameservers = [
      "192.168.1.30" # adguard microVM
      "1.1.1.1"
    ];
  };

  ############################################################
  # MicroVM host + bridge wiring
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

    adguard = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
  };

  # Bridge all VM TAPs onto LAN
  systemd.network.networks."30-lan-vm-taps" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  system.stateVersion = "23.05";
}
