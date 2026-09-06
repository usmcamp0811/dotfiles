{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    # Optionally use graphical installer instead:
    # "${modulesPath}/installer/cd-dvd/installation-cd-graphical-gnome.nix"
  ];

  # Set the hostname for the live environment
  networking.hostName = "nixos-installer";

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Set a default password for the nixos user (change this!)
  users.users.nixos = {
    password = "nixos";
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
  };

  # Enable sudo without password for wheel group (convenient for installation)
  security.sudo.wheelNeedsPassword = false;

  # Include useful tools for installation
  environment.systemPackages = with pkgs; [
    # Text editors
    vim
    neovim
    nano

    # Disk tools
    gptfdisk
    parted
    cryptsetup

    # Network tools
    wget
    curl
    git

    # System tools
    htop
    tmux
    btop
    pciutils
    usbutils

    # Useful for debugging
    lshw
    smartmontools
  ];

  # Enable flakes for installation
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Include your flake in the ISO (optional but useful)
  # This embeds your dotfiles so you can install directly from the USB
  # Uncomment if you want to include your full config:
  # isoImage.contents = [
  #   {
  #     source = ./../..;
  #     target = "/dotfiles";
  #   }
  # ];

  # Or clone from git during installation instead (recommended)
  isoImage.appendToMenuLabel = " Campground Installer";

  # Increase the image size if needed (in MB)
  # isoImage.isoBaseName = "nixos-campground";

  # Enable networking in the installer
  networking.networkmanager.enable = true;
  networking.wireless.enable = false; # Conflicts with NetworkManager

  # Set timezone for convenience
  time.timeZone = "America/New_York"; # Adjust to your timezone

  # Enable guest additions if you want to test in a VM
  virtualisation.vmware.guest.enable = false;
  virtualisation.virtualbox.guest.enable = false;

  # Kernel modules that might be useful for various hardware
  boot.kernelModules = ["kvm-intel" "kvm-amd"];

  # Increase boot verbosity
  boot.kernelParams = ["boot.shell_on_fail"];

  system.stateVersion = "26.05";
}
