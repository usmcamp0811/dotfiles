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
    suites = {
      common = enabled;
      observability = enabled;
    };
    system = {
      # passwds = enabled;
    };
    services = {
      ntp = enabled;
      tang = enabled;
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
      extraGroups = ["wheel"];
      uid = 1000;
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
      # Update flake reference (optional - allows VM updates without host rebuild)
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
  };

  # Network configuration
  # MicroVMs use macvtap to appear as separate devices on the network (no bridge needed)

  # State version
  system.stateVersion = "23.05";
}
