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

  mini-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "mini-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "echasnovski";
      repo = "mini.nvim";
      rev = "main";
      sha256 = "sha256-2wRRP+RnN726nUZ2kbpMRCPiNxPhn8vrrbY7is+u3Ug=";
    };
  };

  nvim-web-devicons = pkgs.vimUtils.buildVimPlugin {
    name = "nvim-web-devicons";
    src = pkgs.fetchFromGitHub {
      owner = "nvim-tree";
      repo = "nvim-web-devicons";
      rev = "master";
      sha256 = "sha256-j/B/E1VltJ/QpVFtDKAdVC4+KZ5Mz8dQP5kd8HIHjLs=";
    };
  };

in {
  extraPlugins = [
    tree-sitter-latex
    mini-nvim
    nvim-web-devicons
    tree-sitter-markdown
    markdown-nvim
  ];
  extraConfigLua = ''
    require('render-markdown').setup({})
  '';
}
