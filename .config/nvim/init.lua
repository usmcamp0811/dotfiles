

-- Base Settings
require("user.options")
require("user.keymaps")
require("user.lsp")
require("user.autocommands")

-- Plugins
require("user.plugins")

-- Plugin Configurations
 require("user.plug-setting.catppuccin")
 require("user.plug-setting.conjure")
 require("user.plug-setting.cmp")
 require("user.plug-setting.telescope")
 require("user.plug-setting.pandoc")
 require("user.plug-setting.treesitter")
 require("user.plug-setting.markid")
 require("user.plug-setting.whichkey")
 require("user.plug-setting.toggleterm")
 require("user.plug-setting.alpha")
 require("user.plug-setting.comment")
 require("user.plug-setting.autopairs")
 require("user.plug-setting.lualine")
 require("user.plug-setting.bufferline")
 require("user.plug-setting.impatient")
 require("user.plug-setting.scrollbars")
 require("user.plug-setting.hlslens")
 require("user.plug-setting.project")
 require("user.plug-setting.nvim-tree")
 require("user.plug-setting.markdown")
 require("user.plug-setting.colorizer")
 require("user.plug-setting.calendar")
 require("user.plug-setting.knap")
 require("user.plug-setting.autosave")
 require("user.plug-setting.vim-ipython-cell")
 require("user.plug-setting.slime")
 require("user.plug-setting.ranger")
 require("user.plug-setting.pretty-fold")
 require("user.plug-setting.gitsigns")
 require("user.plug-setting.neorg")
 require("user.plug-setting.vimwiki")
 require("user.plug-setting.literate")
 require("user.plug-setting.zen")
 -- require("user.plug-setting.image")
 require("user.plug-setting.mind")
 require("user.plug-setting.julia")
 require("user.plug-setting.codewindow")
 -- require("user.julia_tests")
 require("user.plug-setting.leap")
 require('hologram').setup{
    auto_display = true -- WIP automatic markdown image display, may be prone to breaking
}

require'telescope'.setup {
  extensions = {
    media_files = {
      -- filetypes whitelist
      -- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
      filetypes = {"png", "webp", "jpg", "jpeg"},
      find_cmd = "rg" -- find command (defaults to `fd`)
    }
  },
}
-- my own thing's

require("user.code_blocks")

vim.g.sexp_filetypes = "clojure,scheme,lisp,timl,neorg,norg"

vim.cmd("source $HOME/.config/nvim/functions.vim") -- has a function for my markdown code blocks
vim.cmd([[ 
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
]])

-- local dirman = require("neorg.modules.core.norg.dirman.module")
-- local gtd = require("neorg.modules.core.gtd.base.module")
-- local function physical_workspace()
-- 	return dirman.public.get_current_workspace()[1]
-- end
-- local function change_gtd_workspace()
-- 	gtd.config.public["workspace"] = physical_workspace()
-- end
-- local function reload_gtd()
-- 	return neorg.modules.load_module("core.gtd.base")
-- end
-- change_gtd_workspace()
-- reload_gtd()
-- vim.cmd([[colorscheme synthwave84]])

vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = require("lspsaga.lightbulb").action_lightbulb,
})

vim.cmd([[
  augroup numbertoggle
    autocmd!
    autocmd FocusGained,FileType mind setlocal norelativenumber
    autocmd FocusGained,FileType mind setlocal nonumber
    autocmd FocusGained,FileType mind setlocal rnu!
    autocmd FocusGained,FileType mind setlocal nu!
  augroup END
  " highligh default success guifg=green
  " highligh default fail guifg=red
]])

