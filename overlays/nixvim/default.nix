{ nix-vim, unstable, ... }:

final: prev:

{
  nixvim = nix-vim.legacyPackages.${prev.system};
  vimPlugins = unstable.legacyPackages.${prev.system}.vimPlugins;
  nixvimLib = nix-vim.lib.${prev.system};

}
