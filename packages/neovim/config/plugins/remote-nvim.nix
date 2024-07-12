{ pkgs, ... }:
let

  remote-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "remote-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "amitds1997";
      repo = "remote-nvim.nvim";
      rev = "v0.3.11";
      sha256 = "sha256-ado876vs1D1tEQu+Q3jDUaJA9hf/9Y5JLCWu3rf219s=";
    };
  };

in {
  extraPlugins = [ remote-nvim ];
  extraConfigLua = ''
    require("remote-nvim").setup()
  '';
}
