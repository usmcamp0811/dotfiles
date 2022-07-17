require "user.options"
require "user.keymaps"
require "user.plugins"
require "user.colorscheme"
require "user.cmp"
require "user.lsp"
require "user.telescope"
require "user.treesitter"
require "user.whichkey"
require "user.toggleterm"
require "user.alpha"

vim.cmd "source $HOME/.config/nvim/plug-config/lightline.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/ranger.vim"

vim.cmd "source $HOME/.config/nvim/plug-config/slime.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/codi.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/jupyter-vim.vim"  -- allows for julia cell jumping
vim.cmd "source $HOME/.config/nvim/plug-config/autosave.vim"
-- local Plug = vim.fn['plug#']
-- vim.call('plug#begin', '~/.config/nvim/plugged')
-- Plug('nvim-lua/completion-nvim')
-- Plug "williamboman/nvim-lsp-installer"
-- Plug "neovim/nvim-lspconfig"
-- vim.call('plug#end')

