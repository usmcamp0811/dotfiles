{ pkgs
, inputs
, lib
, nixos-hardware
, nixosModules
, ...
}:
with lib;
with lib.fmf; let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in
{
  # home-manager.users.ec2-user.snowfallorg.user.name = "ec2-user";

  ###### REQUIRED FOR EC2 SYSTEMS #######
  boot.loader.grub = { device = "nodev"; };
  # as long as we use the same AMI this works else have to see what the drives are called
  fileSystems."/" = {
    device = "/dev/xvda2";
    fsType = "ext4";
  };
  ###### REQUIRED FOR EC2 SYSTEMS #######

  fmf = {
    nix = enabled;
    cli-apps = { flake = enabled; };
    tools = {
      git = enabled;
      misc = enabled;
    };
    services = {
      openssh = enabled;
      vault = {
        # enable = true;
        ui = true;
        storage = {
          backend = "file";
          path = "/persist/vault";
        };
      };
    };
    system = {
      fonts = enabled;
      locale = enabled;
      time = enabled;
      xkb = enabled;
    };
    user = {
      name = "ec2-user";
      fullName = "Matt";
      email = "mcamp@ata-llc.com";
      extraGroups = [ "wheel" ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
