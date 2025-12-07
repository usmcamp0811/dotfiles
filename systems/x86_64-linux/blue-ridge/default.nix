{
  lib,
  pkgs,
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
    archetypes.server.enable = true;
    system.zfs.enable = mkForce false;

    # User configuration
    user = {
      name = "admin";
      fullName = "System Administrator";
      email = "admin@blue-ridge.local";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    # Services
    services = {
      openssh.enable = true;
      ldap-client.enable = mkForce false;
    };
  };

  # Additional packages
  environment.systemPackages = with pkgs; [
    htop
    vim
    tmux
  ];

  # State version
  system.stateVersion = "23.05";
}
