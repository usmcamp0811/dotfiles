{ nix-vim, nixpkgs, myvim, unstable, ... }:
final: prev: {
  nixvim = nix-vim.legacyPackages.${prev.system};
  vimPlugins = unstable.legacyPackages.${prev.system}.vimPlugins;
  stable-vimPlugins = nixpkgs.legacyPackages.${prev.system}.vimPlugins;
  nixvimLib = nix-vim.lib.${prev.system};
  neovim = myvim.packages.${prev.system}.neovim;
}
