M = {}
local opts = { noremap = true, silent = true }
local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Better window navigation
keymap("n", "<m-h>", "<C-w>h", opts)
keymap("n", "<m-j>", "<C-w>j", opts)
keymap("n", "<m-k>", "<C-w>k", opts)
keymap("n", "<m-l>", "<C-w>l", opts)

-- Tabs --
keymap("n", "<enter>", ":tabnew %<cr>", opts)
keymap("n", "<s-enter>", ":tabclose<cr>", opts)
keymap("n", "<m-\\>", ":tabonly<cr>", opts)

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- save files
keymap("i", "<C-s>", "<esc>:w<cr>", opts)
keymap("n", "<C-s>", ":w<cr>", opts)
-- exit with ctr + q
keymap("n", "<C-q>", "<esc>:q<cr>", opts)
keymap("n", "<C-q>", ":q<cr>", opts)

-- Yank from cursor to end of line
keymap("n", "Y", "y$", opts)

-- Tab lines right
keymap("v", "<Tab>", ">", opts)
-- Tab lines left
keymap("v", "<S-Tab>", "<", opts)

-- Window Pane Resizing Horizontal
keymap("n", "+", "+5 <CR>", opts)
keymap("n", "-", "-5 <CR>", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)


-- Scroll down 5 rows at a time
keymap("n", "<C-j>", "5<C-e>", opts)
-- Scroll up 5 rows at a time
keymap("n", "<C-k>", "5<C-y>", opts)

-- toggle unprintable characters in all modes
keymap("n", "<F8>", ":set list!<CR>", opts)
keymap("i", "<F8>", "<C-o>:set list!<CR>", opts)
keymap("c", "<F8>", "<C-c>:set list!<CR>", opts)

-- Re-source init.vim
keymap("n", "<leader>.", ":source ~/.config/nvim/init.lua<CR>", opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

keymap("n", "<BS>", "<Plug>(comment_toggle_current_linewise)<cr>", opts)

keymap("v", "<BS>", "<Plug>(comment_toggle_linewise_visual)<cr>", opts)

-- Insert current time... for diary/notes
keymap("n", "T", ":r! date +'\\%H:\\%M - '<CR>A", opts)

-- Terminal --
-- Better terminal navigation
-- keymap("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
-- keymap("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
-- keymap("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
-- keymap("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)

-- keymap("v", "u", "<Plug>SnipRun", term_opts)
-- keymap("n", "<leader>u", "<Plug>SnipRunOperator", term_opts)
-- keymap("n", "<leader>uu", "<Plug>SnipRun", term_opts)

keymap("n", "<leader>lv", "<Cmd>lua require('virtual_text').toggle()<CR>", opts)

return M
