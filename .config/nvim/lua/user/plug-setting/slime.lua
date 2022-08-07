M = {}
-- local opts = { noremap = true, silent = true }
-- local term_opts = { silent = true }
--
-- -- Shorten function name
-- local keymap = vim.api.nvim_set_keymap

-- keymap("x", "<leader><cr>", "<Plug>SlimeRegionSend", opts)
-- keymap("n", "<leader><cr>", "<Plug>SlimeParagraphSend", opts)
-- keymap("n", "<leader>v", "<Plug>SlimeConfig", opts)

-- vim.g.slime_target = "tmux"
vim.g.slime_target = "neovim"
-- vim.g.slime_target = "x11"
-- vim.g.slime_default_config = {"socket_name": "default", "target_pane": "{last}"}
vim.g.slime_cell_delimiter = "```"
vim.g.slime_dont_ask_default = 1
-- " let g:slime_cell_delimiter = "# %%"
-- " let g:slime_cell_delimiter = "# {{{"

vim.cmd [[
  function! _EscapeText_rmarkdown(text)
    " Remove all fences
    let trimmed = substitute(a:text, '```{.*}\n', '', 'g')
    let trimmed = substitute(trimmed, '```\n', '', 'g')
    " Detect language
    if match(a:text,'```{python}') > -1
      return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, trimmed, "--\n"]
    else
      return [trimmed]
    endif
  endfunction

" autocmd Filetype python nnoremap <leader>s :call StartIPython()<CR>

autocmd TermOpen * setlocal nonumber norelativenumber

function StartClojure()
    :ToggleTerm direction=vertical size=70 cmd=clj
    :$
    :call SlimeOverrideConfig()
    :SlimeSend1 clear
    :SlimeSend1 clj
endfunction

]]

return M
