{ pkgs, lib, nixos-hardware, agenix, ... }:

with lib;
with lib.internal;
let
  mysecrets = builtins.fetchGit {
    url = "https://gitlab.com/usmcamp0811/campground-secrets.git";
    ref = "master"; 
    rev = "57228b7bbd48b88a6660f6d2a9540be893e76976"; 
  };
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
    # ... any other common settings ...
  };
  # agenix = 
  #   url = "github:yaxitech/ragenix";
  #   flake = false;
  # };
in
{
  imports = [ ./hardware.nix agenix.nixosModules.default ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
    };

    system = {
      boot = enabled;
    };

    hardware.audio = {
    };
  };

  campground.home.extraOptions = {
  };

  campground.user = {
    name = "mcamp";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };

  campground.services.openssh = {
    
  };

  # agenix.secrets."test" = {
  #   # wether secrets are symlinked to age.secrets.<name>.path
  #   symlink = true;
  #   # target path for decrypted file
  #   path = "/etc/some-secret-file";
  #   # encrypted file path
  #   file =  "${mysecrets}/test.age";  # refer to ./xxx.age located in `mysecrets` repo
  #   mode = "0400";
  #   owner = "root";
  #   group = "root";
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
