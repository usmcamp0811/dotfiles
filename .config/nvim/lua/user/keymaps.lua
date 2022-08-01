M = {}
local opts = { noremap = true, silent = true }
-- local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- -- Tabs --
-- keymap("n", "<enter>", ":tabnew %<cr>", opts)
-- keymap("n", "<s-enter>", ":tabclose<cr>", opts)
-- keymap("n", "<C-\\>", ":tabonly<cr>", opts)

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
keymap("", ",", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Terminal --
-- Better terminal navigation
-- keymap("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
-- keymap("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
-- keymap("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
-- keymap("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)

-- keymap("v", "u", "<Plug>SnipRun", term_opts)
-- keymap("n", "<leader>u", "<Plug>SnipRunOperator", term_opts)
-- keymap("n", "<leader>uu", "<Plug>SnipRun", term_opts)

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

-- Normal --
which_key.register({
-- Better window navigation
  ["<C-h>"] = { "<C-w>h", "Move One Window Left"},
  ["<C-j>"] = { "<C-w>j", "Move One Window Down"},
  ["<C-k>"] = { "<C-w>k", "Move One Window Up"},
  ["<C-l>"] = { "<C-w>l", "Move One Window Right"},
-- Buffer navigation
  ["<S-l>"] = { ":bnext<CR>", "Next Buffer"},
  ["<S-h>"] = { ":bprevious<CR>", "Previous Buffer"},
  ["<C-s>"] = { ":w<CR>", "Save"},
  ["<C-q>"] = { ":q<CR>", "Quit"},
  Y = { "y$", "Yank from cursor to end of line"},
  ["<C-Up>"] = { ":resize -2<CR>", "Decrease Current Window Size Horizontally"},
  ["<C-Down>"] = { ":resize +2<CR>", "Increase Current Window Size Vertically"},
  ["<C-Left>"] = { ":vertical -2<CR>", "Decrease Current Window Size Horizontally"},
  ["<C-Right>"] = { ":vertical +2<CR>", "Increase Current Window Size Vertically"},
-- Scroll 5 rows at a time
  ["<S-j>"] = { "5<C-e>", "Scroll down 5 rows at a time"},
  ["<S-k>"] = { "5<C-y>", "Scroll up 5 rows at a time"},
  T = { ":r! date +'\\%H:\\%M - '<CR>A", "Insert Current Time"},
  ["<F8>"] = { ":set list!<CR>", "Toggle Unprintable Charactes" },
})

-- Visual Block --
which_key.register({
  J = { ":move '>+1<CR>gv-gv", "Move Text Down"},
  K = { ":move '<-2<CR>gv-gv", "Move Text Up"},
  ["<Tab>"] = { ">", "Move Text Right" },
  ["<S-Tab>"] = { "<", "Move Text Left" },
}, { mode = "x" })

-- Visual --
which_key.register({
  p = { '"_dP', "Paste without overwriting the register" },
}, { mode = "v" })

-- Command --
which_key.register({
  ["<F8>"] = { "<C-o>:set list!<CR>", "Toggle Unprintable Charactes" },
}, { mode = "c" })

-- Insert --
which_key.register({
  ["<C-s>"] = { "<esc>:w<cr>", "Save" },
  ["<C-q>"] = { "<esc>:q<cr>", "Quit" },
  ["<F8>"] = { "<C-o>:set list!<CR>", "Toggle Unprintable Charactes" },
}, { mode = "i" })

return M

