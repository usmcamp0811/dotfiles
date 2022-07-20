-- Base Settings
require "user.options"
require "user.keymaps"
require "user.lsp"
require "user.autocommands"
require "user.colorscheme"

-- Plugins
require "user.plugins"

-- Plugin Configurations
require "user.plug-setting.cmp"
require "user.plug-setting.telescope"
require "user.plug-setting.treesitter"
require "user.plug-setting.whichkey"
require "user.plug-setting.toggleterm"
require "user.plug-setting.alpha"
require "user.plug-setting.comment"
require "user.plug-setting.autopairs"
require "user.plug-setting.lualine"
require "user.plug-setting.bufferline"
require "user.plug-setting.impatient"
require "user.plug-setting.project"
require "user.plug-setting.nvim-tree"
require "user.plug-setting.plug-colorizer"
require "user.plug-setting.slime"
require "user.plug-setting.julia"
-- require "user.plug-setting.sniprun"


-- TODO: port what I can (below) to Lua
vim.cmd "source $HOME/.config/nvim/autocmds.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/ranger.vim"

vim.cmd "source $HOME/.config/nvim/plug-config/slime.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/codi.vim"
-- vim.cmd "source $HOME/.config/nvim/plug-config/jupyter-vim.vim"  -- allows for julia cell jumping
vim.cmd "source $HOME/.config/nvim/plug-config/autosave.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/sneak.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/quickscope.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/vimwiki.vim"

-- $HOME/.config/nvim/lua/user/plugins.lua
