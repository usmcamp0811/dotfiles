{ pkgs, ... }: {
  # use the ayu theme
  imports = [ ./plugins/ayu.nix ];

  colorschemes = {
    catppuccin = {
      enable = false;
      # background = { dark = "mocha"; };
      settings = { background = { dark = "mocha"; }; };
    };
    nord = { enable = false; };
    onedark = { enable = false; };
  };
}
