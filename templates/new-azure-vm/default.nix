{ pkgs, config, lib, nixos-hardware, nixosModules, ... }:
with lib;
with lib.fmf;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in
{
  boot.loader.grub = { device = "nodev"; };
  # as long as we use the same AMI this works else have to see what the drives are called
  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/sda2";
    fsType = "ext4";
  };

  fmf = {
    archetypes.barebones = enabled;

    user = {
      name = "adminuser";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" ];
    };

    services = {
      openssh = {
        enable = true;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGw+o+9F4kz+dYyI2I4WudgKjyFOK+L0QW4LhxkG4sMt gitlab-runner@aicampground.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdMWMFyi7Lvjm78KOX3tKZ5bkEZ7bHA56ZKKtTb9wIo mcamp@aicampground.com"
        ];
      };
      ntp = enabled;
    };
  };

  system.stateVersion = "23.05";
}
