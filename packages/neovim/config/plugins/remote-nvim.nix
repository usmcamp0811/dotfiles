{ pkgs, ... }:
let

in
# nui = pkgs.vimUtils.buildVimPlugin {
#   name = "nui";
#   src = pkgs.fetchFromGitHub {
#     owner = "MunifTanjim";
#     repo = "nui.nvim";
#     rev = "v0.3.0";
#     sha256 = "";
#   };
# };
# remote-nvim = pkgs.vimUtils.buildVimPlugin {
#   name = "remote-nvim";
#   src = pkgs.fetchFromGitHub {
#     owner = "amitds1997";
#     repo = "remote-nvim.nvim";
#     rev = "v0.3.11";
#     sha256 = "sha256-ado876vs1D1tEQu+Q3jDUaJA9hf/9Y5JLCWu3rf219s=";
#   };
# };
{
  extraPlugins = [
    # remote-nvim
    # nui
  ];
  # extraConfigLua = ''
  #   require("remote-nvim").setup()
  # '';
}
