{ pkgs, ... }: {

  # use the ayu theme
  imports = [ ./plugins/ayu.nix ];

  # leaving below as examples and also in case I wanna change quickly
  colorschemes = {
    catppuccin = {
      enable = false;
      background = { dark = "mocha"; };
    };
    nord = { enable = false; };
    onedark = { enable = false; };
  };

}

