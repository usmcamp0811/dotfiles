{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [fold-preview-nvim];

  extraConfigLua = ''
    require("fold-preview").setup()
  '';
}
