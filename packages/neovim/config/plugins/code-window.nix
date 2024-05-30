{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [codewindow-nvim];

  extraConfigLua = ''
    codewindow = require("codewindow")
    codewindow.setup()
    codewindow.apply_default_keybinds()
  '';
}
