{ pkgs, ... }:
let

  markdown-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "markdown-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "MeanderingProgrammer";
      repo = "markdown.nvim";
      rev = "main";
      sha256 = "sha256-wziuBuHP8ks+9I/T6W149+MMEPKtPnxgyLqjT0Q/W50=";
    };
  };
  tree-sitter-markdown = pkgs.vimUtils.buildVimPlugin {
    name = "tree-sitter-markdown";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter-grammars";
      repo = "tree-sitter-markdown";
      rev = "main";
      sha256 = "sha256-wt10tW+PS3LfgKhvgOAX9IDFpyKAe3AIoGbXFhYFnw8=";
    };
  };
  tree-sitter-latex = pkgs.vimUtils.buildVimPlugin {
    name = "tree-sitter-latex";
    src = pkgs.fetchFromGitHub {
      owner = "latex-lsp";
      repo = "tree-sitter-latex";
      rev = "master";
      sha256 = "sha256-QOlnE5JnJHdupL12YMT6cIRcP/2GKsewPkRuWwAwliI=";
    };
  };

in {
  extraPlugins = [
    tree-sitter-latex
    pkgs.vimPlugins.mini-nvim
    pkgs.vimPlugins.nvim-web-devicons
    tree-sitter-markdown
    markdown-nvim
  ];
  extraConfigLua = ''
    require('render-markdown').setup({})
  '';
}
