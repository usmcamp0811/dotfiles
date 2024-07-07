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
in {
  extraPlugins = [ tree-sitter-markdown markdown-nvim ];
  extraConfigLua = ''
    require('render-markdown').setup({})
  '';
}
