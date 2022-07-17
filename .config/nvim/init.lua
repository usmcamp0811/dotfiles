-- Base Settings
require "user.options"
require "user.keymaps"
require "user.lsp"

-- Plugins
require "user.plugins"

-- Plugin Configurations
require "user.plug-setting.colorscheme"
require "user.plug-setting.cmp"
require "user.plug-setting.telescope"
require "user.plug-setting.treesitter"
require "user.plug-setting.whichkey"
require "user.plug-setting.toggleterm"
require "user.plug-setting.alpha"
require "user.plug-setting.comment"
require "user.plug-setting.autopairs"

-- TODO: port what I can (below) to Lua
-- vim.cmd "source $HOME/.config/nvim/autocmds.vim"
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

