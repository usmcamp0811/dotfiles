{ pkgs, ... }:
let

  markdown-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "markdown-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "MeanderingProgrammer";
      repo = "markdown.nvim";
      rev = "v3.3.1";
      sha256 = "sha256-r615Iug6Nv8svduRqyEjEuzW/lIwaY2zbZGuNfYjmj0=";
    };
  };
  tree-sitter-markdown = pkgs.vimUtils.buildVimPlugin {
    name = "tree-sitter-markdown";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter-grammars";
      repo = "tree-sitter-markdown";
      rev = "v0.2.3";
      sha256 = "sha256-B6aBF3T/9zunRSUNRgCyMjcp/slXWimiWTWmJI5qvqE=";
    };
  };
  tree-sitter-latex = pkgs.vimUtils.buildVimPlugin {
    name = "tree-sitter-latex";
    src = pkgs.fetchFromGitHub {
      owner = "latex-lsp";
      repo = "tree-sitter-latex";
      rev = "v0.4.0";
      sha256 = "sha256-B6aBF3T/9zunRSUNRgCyMjcp/slXWimiWTWmJI5qvqE=";
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
