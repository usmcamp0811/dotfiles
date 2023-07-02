# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  mcamp = import ../users/mcamp/user.nix;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  networking.hostName = "nixos"; # Define your hostname.
#  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    windowManager.qtile = {
      enable = true;
    };
    layout = "us";
    xkbVariant = "";
  };

  users.users.mcamp = {
    isNormalUser = mcamp.isNormalUser;
    description = mcamp.description;
    extraGroups = mcamp.extraGroups;
    # shell = mcamp.shell;
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    gcc
    rsync
    neovim
    git
    xdg_utils
    xdg-user-dirs
    tpm2-tools
    clevis
    ranger
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    bashInteractive
    less
    bc
    lsd
    colordiff
    fzf
    ripgrep
    jq
    rsync
    tmux
    tmuxp
    dejavu_fonts
    bat
    python3Packages.pynvim
    pbzip2
    shellcheck
    docker
    docker-compose
    tldr
    wget
    unzip
    syncthing
    fuse
    nfs-utils
    tldr
    qtile
    lightdm
    netcat-gnu
    # nur.repos.kira-bruneau.themes.lightdm-webkit2-greeter.litarvan
  ];



  programs.zsh.enable = true;
  services.openssh.enable = true;
  hardware.pulseaudio.enable = true;
  sound.enable = true;
  hardware.pulseaudio.systemWide = true;
  services.xserver.displayManager.defaultSession = "none+qtile";
  services.logind.lidSwitch = "ignore";
  system.stateVersion = "23.11"; # Did you read the comment?

  system.autoUpgrade = {
  	enable = true;
	  channel = "httpsL//nixos.org/channels/nixos-unstable";
  };

  nix = {
    settings.auto-optimise-store = true;
    extraOptions = "experimental-features = nix-command flakes";
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  virtualisation.docker.enable = true;

}
