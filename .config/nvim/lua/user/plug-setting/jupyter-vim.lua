-- local opts = { noremap = true, silent = true }
-- local term_opts = { silent = true }

-- Shorten function name
-- local keymap = vim.api.nvim_set_keymap

vim.g.python3_host_prog = "python3"
vim.g.jupyter_mapkeys = 0

vim.keymap.set("n", "<localleader>f", ":JupyterRunFile<cr>", { desc="Execute Code" })
