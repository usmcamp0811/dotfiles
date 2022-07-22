-- Base Settings
require "user.options"
require "user.keymaps"
require "user.lsp"
require "user.autocommands"
require "user.colorscheme"

-- Plugins
require "user.plugins"
-- $HOME/.config/nvim/lua/user/plugins.lua

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
require "user.plug-setting.catppuccin"
require "user.plug-setting.markdown"
require "user.plug-setting.telekasten"


-- TODO: port what I can (below) to Lua
vim.cmd "source $HOME/.config/nvim/autocmds.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/ranger.vim"

vim.cmd "source $HOME/.config/nvim/plug-config/slime.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/codi.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/autosave.vim"
vim.cmd "source $HOME/.config/nvim/plug-config/jupyter-vim.vim"  -- allows for julia cell jumping
vim.cmd "source $HOME/.config/nvim/plug-config/pandoc.vim"
vim.cmd "source $HOME/.config/nvim/functions.vim" -- has a function for my markdown code blocks
vim.cmd [[ 
function! s:isAtStartOfLine(mapping)
  let text_before_cursor = getline('.')[0 : col('.')-1]
  let mapping_pattern = '\V' . escape(a:mapping, '\')
  let comment_pattern = '\V' . escape(substitute(&l:commentstring, '%s.*$', '', ''), '\')
  return (text_before_cursor =~? '^' . ('\v(' . comment_pattern . '\v)?') . '\s*\v' . mapping_pattern . '\v$')
endfunction

inoreabbrev <expr> <bar><bar>
          \ <SID>isAtStartOfLine('\|\|') ?
          \ '<c-o>:TableModeEnable<cr><bar><space><bar><left><left>' : '<bar><bar>'
inoreabbrev <expr> __
          \ <SID>isAtStartOfLine('__') ?

let g:ipython_cell_regex = 1
let g:ipython_cell_tag = '```( [^[].*)?'
let g:julia_cell_delimit_cells_by = 'marks'
let g:ipython_language = "Julia"
let g:ipython_cell_run_command = 'include("{filepath}")'
let g:ipython_cell_cell_command = 'include_string(Main, clipboard())'
]]
