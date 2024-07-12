{ pkgs, ... }:
let

  remote-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "markdown-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "amitds1997";
      repo = "remote-nvim.nvim";
      rev = "v0.3.11";
      sha256 = "";
    };
  };

in {
  extraPlugins = [ remote-nvim ];
  # extraConfigLua = ''
  #   require('render-markdown').setup({})
  # '';
}
