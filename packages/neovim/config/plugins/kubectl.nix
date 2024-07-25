{ pkgs, ... }:
let
  kubectl = pkgs.vimUtils.buildVimPlugin {
    name = "kubectl.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "Ramilito";
      repo = "kubectl.nvim";
      rev = "0.2.0";
      sha256 = "sha256-cPS/PVwZZRgnmOy0WH3yVnZV8rrVCTMFu/hr33M+CB8=";
    };
  };
in {
  extraPlugins = [ kubectl ];
  extraConfigLua = ''
    require("kubectl").setup()
  '';
}
