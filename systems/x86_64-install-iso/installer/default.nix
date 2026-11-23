# The fmf live ISO: boot it on a new machine, get a Hyprland desktop with a terminal, a browser and
# Vault, and everything needed to partition, install and bootstrap a host from a flake.
#
#   nix build .#install-isoConfigurations.installer     # the image is in result/iso/
#
# Docs: docs/INSTALL-NIXOS.md. It is built and published monthly by CI.
#
# The intent: boot the USB on a new machine, then SSH in from a working computer and drive the install
# from there, with the tools already on the image.
#
# This image is public, so it is deliberately narrow about who can get in and what it carries:
#   * one SSH key is baked in, mine (below), for the live user and for root, and nothing else can log
#     in: neither account has a password;
#   * it does not use an archetype, because `fmf.suites.common` enables a Crystal Forge agent and
#     caches that belong to my fleet.
{
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; {
  home-manager.users.nixos.snowfallorg.user.name = "nixos";

  boot.kernelModules = ["igb"];

  # Crystal Forge's STIG presets are on by default for hosts that import its modules.
  crystal-forge.stig-presets.off.enable = true;

  # NetworkManager (pulled in by fmf.hardware.networking) handles Wi-Fi: nm-applet in the bar,
  # `nmtui` in a terminal.
  networking.wireless.enable = mkForce false;

  # Text-to-speech is on by default with a desktop and adds hundreds of MB of voices to the image.
  services.speechd.enable = mkForce false;

  fmf = {
    nix = enabled;
    cli-apps = {flake = enabled;};
    tools = {git = enabled;};
    hardware = {
      audio = {
        enable = true;
        # EasyEffects pulls in LV2 plugin packs; a live USB does not need an equalizer.
        include-easyeffects = false;
        extra-packages = [];
      };
      networking = enabled;
    };
    system = {
      fonts = enabled;
      locale = enabled;
      time = enabled;
      xkb = enabled;
      # No `zfs = enabled` here: that is my Tang/Clevis network-unlock setup for my
      # servers. It pins an old kernel and turns on an NFS server and initrd networking. The
      # installer's base profile already provides ZFS support on the default kernel.
    };

    # Hyprland, the SDDM greeter, kitty, the theme and the wallpapers: my default desktop.
    suites.desktop = enabled;
    desktop.qtile.enable = mkForce false;

    services.openssh = {
      enable = true;
      # The only key accepted, for the live user and for root: boot the USB, then `ssh nixos@<ip>`
      # from a working computer. This replaces fmf's defaults (more of my keys) with just this one.
      # To use your own image, put your key here.
      authorizedKeys = mkForce [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler"
      ];
      manage-other-hosts = false;
    };

    user = {
      name = "nixos";
      fullName = "fmf live user";
      email = "nixos@localhost";
      extraGroups = ["wheel"];
      # No "password" account on a public image; the live user logs in without one, as on the
      # official installer.
      initialPassword = null;
    };
  };

  # Log in to the desktop automatically, like the official graphical installer.
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "nixos";
    };
    defaultSession = "hyprland";
  };

  environment.systemPackages = with pkgs; [
    fmf.install-scripts

    # Get a flake and install from it
    git
    disko
    nixos-install-tools

    # Disks
    parted
    gptfdisk
    cryptsetup
    btrfs-progs
    e2fsprogs
    dosfstools
    xfsprogs
    ntfs3g
    lvm2
    mdadm
    clevis # unlock a Tang-bound disk while bootstrapping
    nvme-cli
    smartmontools
    hdparm

    # Hardware and network
    pciutils
    usbutils
    lshw
    dmidecode
    ethtool
    iw
    iproute2
    dnsutils
    tcpdump

    # Everyday tools
    vim # not `neovim`: in this flake that is my full distribution (rustc, a JDK, LSPs)
    tmux
    htop
    curl
    wget
    jq
    ripgrep
    rsync
    tree
    unzip
    whois # mkpasswd, for a hashed password file
    openssl
    age

    # Light replacements for what fmf.tools.misc would bring (it also installs gcc, clang, zig, deno)
    fzf
    bat
    lsd
    btop
    fastfetch
    killall
    file
    lsof

    # The desktop's browser
    brave

    # The Vault CLI. The prebuilt binary, so nothing is compiled. VAULT_ADDR is deliberately not
    # set: this image is public, so point it at your own server: `export VAULT_ADDR=https://...`.
    vault-bin
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
