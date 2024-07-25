{ pkgs, ... }:
let
  kubectl = pkgs.vimUtils.buildVimPlugin {
    name = "kubectl.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "Ramilito";
      repo = "kubectl.nvim";
      rev = "0.2.0";
      sha256 = "";
    };
  };
in {
  extraPlugins = [ kubectl ];
  extraConfigLua = ''
    require("kubectl").setup()
  '';
}
