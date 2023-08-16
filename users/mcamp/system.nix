{ config, pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # Add the packages you want to install here
  ];

  # Use modules from the jakehamilton flake
  imports = [
    inputs.jakehamilton.outputs.nixosModules.apps/gimp
  ];

  programs.gimp.enable = true;
}

