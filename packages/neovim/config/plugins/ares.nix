{ pkgs, ... }:
let
  # This works but has some bugs in it
  # I think its due to the theme package execting colors that don't exits
  lush = pkgs.vimUtils.buildVimPlugin {
    name = "lush.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "rktjmp";
      repo = "lush.nvim";
      rev = "main";
      sha256 = "sha256-rTF3QEMf1yls18iZoY2TgTQ5mZn4xttfDlr117hC4Yw=";
    };
  };
  ares = pkgs.vimUtils.buildVimPlugin {
    name = "ares.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "ab-dx";
      repo = "ares.nvim";
      rev = "main";
      sha256 = "sha256-/T23qOtH6ytvdR68QZGemtcH+TpCSjKfLDEhddDN11Q=";
    };
  };
in {
  extraPlugins = [ lush ares ];
  extraConfigLua = ''

    vim.opt.termguicolors = true
    require("lush")(require("ares_theme.ares"))
    vim.cmd([[
    try
      colorscheme ares
    catch /^Vim\%((\a\+)\)\=:E185/
      colorscheme auto
      set background=dark
    endtry
    ]])
  '';
}
