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

    # Networking - appear as separate device on the network
    interfaces = [
      {
        type = "macvtap";
        id = "vm-vault";
        mac = "02:00:00:00:00:10"; # Static MAC for consistent DHCP
        macvtap = {
          link = "enp2s0"; # Physical interface on blue-ridge
          mode = "bridge"; # VM appears as separate device on network
        };
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
        image = "vault-data.img";
        mountPoint = "/var/lib/vault";
        size = 10240; # 10GB for vault data
      }
    ];
  };

  networking.interfaces.eth0.useDHCP = true;
  # Basic system configuration
  campground = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "Vault Administrator";
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

  # # Network configuration - will get IP from blue-ridge's DHCP
  # networking = {
  #   hostName = "vault";
  #   useDHCP = true;
  #   firewall.enable = true;
  # };
  #
  # # Locale
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };
  #
  # # Essential packages
  # environment.systemPackages = with pkgs; [
  #   htop
  #   vim
  #   curl
  # ];

  # Example: Vault service (uncomment when ready to configure)
  # services.vault = {
  #   enable = true;
  #   address = "0.0.0.0:8200";
  #   storageBackend = "file";
  #   storagePath = "/var/lib/vault";
  # };

  system.stateVersion = "23.05";
}
