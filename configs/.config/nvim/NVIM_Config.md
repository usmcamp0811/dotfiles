# Matt's Neovim Config


This is an attempt to refactor and clean up my config, as well as an attempt to make it more literate. 
I am originally writing this in [Neorg](https://github.com/nvim-neorg/neorg) using the `#tangle` module. Eventually I plan to better learn Fennel and convert everything, but until then this is a pure Lua config.



## Base Settings


These are all the non-plugin Neovim settings. I generally try to keep this part clean of
things that need plugins to be installed. 


### Options


In order to minimize verbosity of things I am throwing all the options into a single Lua 
table.

```lua
local options = {

  foldmethod = "syntax",
  directory = vim.fn.stdpath("config") .. "/swaps",
  backupdir = vim.fn.stdpath("config") .. "/backups",
  undodir = vim.fn.stdpath("config") .. "/undo",
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  termguicolors = true,
  clipboard = "unnamedplus",
  autoindent = true,
  diffopt = "filler",
  cursorline = true,
  mouse = "a", -- enable mouse in all modes
  wrap = true, -- don't wrp lines
  magic = true, -- Enable extended regex commands
  joinspaces = false, -- Only insert single space after a '.', '?' and '!' with a join command
  showmode = false, -- Going to use airline.vim to handle this for us
  startofline = false, -- Don't reset cursor to the start of the line when moving around
  ruler = true, -- Show current position
  nu = true, -- enable line numbers
  shell = "/bin/zsh",
  splitbelow = true, -- New windows go below
  splitright = true, -- New windows go right
  title = true, -- Show the filename in the window titlebar
  undofile = true, -- Persistent Undo
  wildmenu = true, -- Hitting TAB in command mode will show possible completion above command line
  wrapscan = true, -- Searches wrap around end of file
  encoding = "utf-8", -- nobomb
  fileencoding = "utf-8",
  -- vim.o.guioptions = 'a' -- copy on select... requires gvim
  shortmess = "atI", -- Don't show the intro message when starting vim
  showtabline = 2, -- Always show tab bar
  sidescrolloff = 3, -- Start scrolling three columns before vertical border of window
  smartcase = true, -- Ignore 'ignorecase' if search patter contains uppercase characters
  smarttab = true, -- At start of line, <Tab> inserts shiftwidth spaces, <Bs> deletes shiftwidth spaces
  scrolloff = 3, -- Start scrolling three lines before horizontal border of window
  lazyredraw = true, -- Don't redraw when we don't have to
  laststatus = 2, -- Always show status line
  spell = true, -- turns on spell check
  relativenumber = true, -- Use relative line numbers. Current line is still in status bar.
  wildignore = {
    ".DS_Store",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.png",
    "*.gif",
    "*.psd",
    "*.o",
    "*.obj",
    "*.min.js",
    "*/bower_components/*",
    "*/node_modules/*",
    "*/smarty/*",
    "*/vendor/*",
    "*/.git/*",
    "*/.hg/*",
    "*/.svn/*",
    "*/.sass-cache/*",
    "*/log/*",
    "*/tmp/*",
    "*/build/*",
    "*/ckeditor/*",
    "*/doc/*",
    "*/source_maps/*",
    "*/dist/*",
  },
  wildmode = "longest,list,full",
  laststatus = 3
}
```


## LSP


My LSP config is a little bastardized as I have borrowed from others and I have had to learn things 
along the way. This first `if` statement is suppose to be here to keep things from breaking should
we not have `lspconfig` installed.

```lua
local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
  return
end
```

In an attempt to keep things organized, I broke the config down in to multiple sections and just 
import them into a single `init.lua`.

```lua
require("user.lsp.configs")
require("user.lsp.handlers").setup()
require("user.lsp.null-ls")
require("user.lsp.mason")
```


### Configs


```lua
local status_ok, lsp_installer = pcall(require, "mason")
if not status_ok then
  return
end

local lspconfig = require("lspconfig")

local servers = { "jsonls", "sumneko_lua", "pyright", "yamlls", "julials", "texlab", "dockerls", "clojure_lsp" }

lsp_installer.setup({
  ensure_installed = servers,
})

for _, server in pairs(servers) do
  local opts = {
    on_attach = require("user.lsp.handlers").on_attach,
    capabilities = require("user.lsp.handlers").capabilities,
  }
  local has_custom_opts, server_custom_opts = pcall(require, "user.lsp.settings." .. server)
  if has_custom_opts then
    opts = vim.tbl_deep_extend("force", opts, server_custom_opts)
  end
  lspconfig[server].setup(opts)
end

```


### Handlers


To be honest I don't have a good explanation of what the Handlers are... 

```lua
local HANDLERS = {}
local navic = require("nvim-navic")
-- TODO: backfill this to template
HANDLERS.setup = function()
  local signs = {
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignHint", text = "" },
    { name = "DiagnosticSignInfo", text = "" },
  }

  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

  local config = {
    virtual_text = false,
    signs = {
      active = signs,
    },
    update_in_insert = true,
    underline = true,
    severity_sort = true,
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
  }

  vim.diagnostic.config(config)

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
    width = 60,
  })

  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
    width = 60,
  })
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    config.virtual_text,
  })
end

local function lsp_highlight_document(client)
  -- Set autocommands conditional on server_capabilities
  local status_ok, illuminate = pcall(require, "illuminate")
  if not status_ok then
    return
  end

  illuminate.on_attach(client)
  -- end
end

HANDLERS.on_attach = function(client, bufnr)
  vim.notify(client.name .. " starting...")
  -- TODO: refactor this into a method that checks if string in list
  if client.name == "tsserver" then
  end
  lsp_keymaps(bufnr)
  lsp_highlight_document(client)
  if client.server_capabilities.documentSymbolProvider then
      navic.attach(client, bufnr)
  end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()

local status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not status_ok then
  return
end

HANDLERS.capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

return HANDLERS

```


### Null-LS

```lua 
local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

local lspconfig = require("lspconfig")

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics
local completions = null_ls.builtins.completion
local hover = null_ls.builtins.hover
local code_actions = null_ls.builtins.code_actions

local on_attach = function(client)
  if client.server_capabilities.document_formatting then
    vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()")
  end
end

null_ls.setup({
debug = false,
sources = {
  formatting.prettier.with({ extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" } }),
  formatting.black.with({ extra_args = { "--fast" } }),
  formatting.stylua,
  formatting.markdownlint,
  formatting.beautysh,
  formatting.bibclean,
  formatting.cljstyle,
  formatting.djhtml,
  formatting.fixjson,
  diagnostics.flake8,
  diagnostics.zsh,
  diagnostics.alex,
  diagnostics.ansiblelint,
  diagnostics.clj_kondo,
  diagnostics.curlylint,
  diagnostics.djlint,
  diagnostics.jsonlint,
  diagnostics.pydocstyle,
  diagnostics.shellcheck,
  diagnostics.vint,
  diagnostics.yamllint,
  code_actions.proselint,
  completions.spell,
  hover.dictionary,
},
debounce = 4000,
on_attach = on_attach, 
```


### Mason


```lua 
local status_ok, mason = pcall(require, "mason")
if not status_ok then
  return
end

local status_ok_1, mason_lspconfig = pcall(require, "mason-lspconfig")
if not status_ok_1 then
  return
end

local servers = {
  "cssls",
  "cssmodules_ls",
  "html",
  "jsonls",
  "sumneko_lua",
  "tsserver",
  "pyright",
  "yamlls",
  "bashls",
  "julials",
}

local settings = {
  ui = {
    border = "rounded",
    icons = {
      package_installed = "◍",
      package_pending = "◍",
      package_uninstalled = "◍",
    },
  },
  log_level = vim.log.levels.INFO,
  max_concurrent_installers = 4,
}

mason.setup(settings)
mason_lspconfig.setup({
  ensure_installed = servers,
  automatic_installation = true,
})

local lspconfig_status_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status_ok then
  return
end

local opts = {}

for _, server in pairs(servers) do
  opts = {
    on_attach = require("user.lsp.handlers").on_attach,
    capabilities = require("user.lsp.handlers").capabilities,
  }

  server = vim.split(server, "@")[1]

  if server == "jsonls" then
    local jsonls_opts = require("user.lsp.settings.jsonls")
    opts = vim.tbl_deep_extend("force", jsonls_opts, opts)
  end

  if server == "yamlls" then
    local yamlls_opts = require("user.lsp.settings.yamlls")
    opts = vim.tbl_deep_extend("force", yamlls_opts, opts)
  end

  if server == "sumneko_lua" then
    local l_status_ok, lua_dev = pcall(require, "lua-dev")
    if not l_status_ok then
      return
    end
    local luadev = lua_dev.setup({
      lspconfig = {
        on_attach = opts.on_attach,
        capabilities = opts.capabilities,
      },
    })
    lspconfig.sumneko_lua.setup(luadev)
    goto continue
  end

  if server == "tsserver" then
    local tsserver_opts = require("user.lsp.settings.tsserver")
    opts = vim.tbl_deep_extend("force", tsserver_opts, opts)
  end

  if server == "pyright" then
    local pyright_opts = require("user.lsp.settings.pyright")
    opts = vim.tbl_deep_extend("force", pyright_opts, opts)
  end

  if server == "solc" then
    local solc_opts = require("user.lsp.settings.solc")
    opts = vim.tbl_deep_extend("force", solc_opts, opts)
  end

  if server == "emmet_ls" then
    local emmet_ls_opts = require("user.lsp.settings.emmet_ls")
    opts = vim.tbl_deep_extend("force", emmet_ls_opts, opts)
  end

  if server == "zk" then
    local zk_opts = require("user.lsp.settings.zk")
    opts = vim.tbl_deep_extend("force", zk_opts, opts)
  end

  if server == "jdtls" then
    goto continue
  end

  if server == "rust_analyzer" then
    local rust_opts = require("user.lsp.settings.rust")
    local rust_tools_status_ok, rust_tools = pcall(require, "rust-tools")
    if not rust_tools_status_ok then
      return
    end

    rust_tools.setup(rust_opts)
    goto continue
  end

  lspconfig[server].setup(opts)
  ::continue::
end
```


## Plugins



### Packer Setup


```lua 
local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
group packer_user_config
autocmd!
autocmd BufWritePost plugins.lua source <afile> | PackerSync
group end


-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  vim.notify("shit broke")
  return
end

packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

return packer.startup(function(use)
use("wbthomason/packer.nvim") -- Have packer manage itself
```


### Lua Utility Plugins


```lua 
use("nvim-lua/popup.nvim") -- An implementation of the Popup API from vim in Neovim
use("nvim-lua/plenary.nvim") -- Useful lua functions used ny lots of plugins
```


### Vim Feature Improvement Plugins


```lua 
use("folke/which-key.nvim")
use("radenling/vim-dispatch-neovim")
use("tpope/vim-dispatch")
use({
  "chentoast/marks.nvim",
  config = function()
    require("user.plug-setting.marks")
  end,
})

-- use "jceb/vim-orgmode"
use({
  "anuvyklack/fold-preview.nvim",
  requires = "anuvyklack/keymap-amend.nvim",
  config = function()
    require("fold-preview").setup()
  end,
})

use({
  "kylechui/nvim-surround",
  tag = "*", -- Use for stability; omit to use `main` branch for the latest features
  config = function()
    require("nvim-surround").setup({
      -- Configuration here, or leave empty to use defaults
    })
  end,
})
use("guns/vim-sexp")
use("tpope/vim-sexp-mappings-for-regular-people")
use("moll/vim-bbye")
use("rcarriga/nvim-notify")
```


#### Toggle Term


```lua 
use("akinsho/toggleterm.nvim")
```

```lua 
local status_ok, toggleterm = pcall(require, "toggleterm")
if not status_ok then
  return
end

toggleterm.setup({
  size = function(term)
    if term.direction == "horizontal" then
      return 15
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping = [[<F1>]],
  hide_numbers = true,
  shade_filetypes = {},
  shade_terminals = false,
  shading_factor = 2,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  direction = "float",
  close_on_exit = true,
  shell = vim.o.shell,
  float_opts = {
    border = "curved",
    winblend = 0,
    highlights = {
      border = "Normal",
      background = "Normal",
    },
  },
})

function _G.set_terminal_keymaps()
  local opts = { noremap = true }
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

function _LAZYGIT_TOGGLE()
  lazygit:toggle()
end

local node = Terminal:new({
  cmd = "node",
  dir = "git_dir",
  direction = "vertical",
  on_open = function()
    vim.g.node_job_id = vim.b.terminal_job_id
  end,
})

function _NODE_TOGGLE()
  node:toggle()
  vim.cmd("wincmd h")
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.node_job_id,
  }
  vim.cmd("wincmd l")
end

local ncdu = Terminal:new({ cmd = "ncdu", hidden = true })

function _NCDU_TOGGLE()
  ncdu:toggle()
end

local bpytop = Terminal:new({ cmd = "bpytop", hidden = true })

function _BPYTOP_TOGGLE()
  bpytop:toggle()
end

local k9s = Terminal:new({ cmd = "k9s", hidden = true })

function _K9S_TOGGLE()
  k9s:toggle()
end

local htop = Terminal:new({ cmd = "htop", hidden = true })

function _HTOP_TOGGLE()
  htop:toggle()
end

local vshell = Terminal:new({
  cmd = "zsh",
  dir = "git_dir",
  direction = "vertical",
  on_open = function()
    vim.g.vshell_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.vshell_job_id = nil
  end,
})

function _VSHELL_TOGGLE()
  vshell:toggle()
  vim.cmd("wincmd h")
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.vshell_job_id,
  }
  vim.cmd("wincmd l")
end

local hshell = Terminal:new({
  cmd = "zsh",
  dir = "git_dir",
  direction = "horizontal",
  on_open = function()
    vim.g.hshell_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.hshell_job_id = nil
  end,
})

function _HSHELL_TOGGLE()
  hshell:toggle()
  vim.cmd("wincmd k")
  vim.g.slime_target = "neovim"
  vim.g.slime_dont_ask_default = 1
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.hshell_job_id,
  }
  vim.cmd("wincmd j")
end

local clojure = Terminal:new({
  cmd = "clj -M:repl/conjure || clojure -M:repl/remote --port 8794 --host localhost",
  dir = "git_dir",
  name = "clojure",
  count = 38,
  direction = "vertical",
  on_open = function()
    vim.g.clojure_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.clojure_job_id = nil
  end,
})

function _CLOJURE_TOGGLE()
  clojure:toggle()
  vim.cmd("wincmd h")
  vim.g.slime_target = "neovim"
  vim.g.slime_dont_ask_default = 1
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.clojure_job_id,
  }
  vim.cmd("wincmd l")
end

local python = Terminal:new({
  cmd = "ipython --matplotlib",
  name = "pyton",
  count = 314,
  dir = "git_dir",
  direction = "vertical",
  on_open = function()
    vim.g.python_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.python_job_id = nil
  end,
  shade_terminals = true,
})

function _PYTHON_TOGGLE()
  python:toggle()
  vim.cmd("wincmd h")
  vim.g.slime_target = "neovim"
  vim.g.slime_dont_ask_default = 1
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.python_job_id,
  }
  vim.cmd("wincmd l")
end

local julia = Terminal:new({
  cmd = "julia",
  name = "julia",
  count = 42,
  dir = "git_dir",
  direction = "vertical",
  on_open = function()
    vim.g.julia_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.julia_job_id = nil
  end,

})

function _JULIA_TOGGLE()
  julia:toggle()
  vim.cmd("wincmd h")
  vim.g.slime_target = "neovim"
  vim.g.slime_dont_ask_default = 1
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.julia_job_id,
  }
  vim.cmd(":let g:julia_bufnr=bufnr('%')")
  vim.cmd("wincmd l")
end

local lua = Terminal:new({
  cmd = "lua",
  dir = "git_dir",
  direction = "vertical",
  on_open = function()
    vim.g.lua_job_id = vim.b.terminal_job_id
  end,
  on_close = function()
    vim.g.lua_job_id = nil
  end,
})

function _LUA_TOGGLE()
  lua:toggle()
  vim.cmd("wincmd h")
  vim.g.slime_target = "neovim"
  vim.g.slime_dont_ask_default = 1
  vim.b.slime_config = {}
  vim.b.slime_config = {
    jobid = vim.g.lua_job_id,
  }
  vim.cmd("wincmd l")
end

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  t = {
    name = "Terminal",
    j = { "<cmd>lua _JULIA_TOGGLE()<cr>", "Julia" },
    c = { "<cmd>lua _CLOJURE_TOGGLE()<cr>", "Clojure" },
    p = { "<cmd>lua _PYTHON_TOGGLE()<cr>", "Python" },
    n = { "<cmd>lua _NODE_TOGGLE()<cr>", "Node" },
    l = { "<cmd>lua _LUA_TOGGLE()<cr>", "Lua" },
    g = { "<cmd>lua _LAZYGIT_TOGGLE()<CR>", "Lazygit" },
    u = { "<cmd>lua _NCDU_TOGGLE()<cr>", "NCDU" },
    t = { "<cmd>lua _HTOP_TOGGLE()<cr>", "Htop" },
    k = { "<cmd>lua _K9S_TOGGLE()<cr>", "K9s" },
    f = { "<cmd>ToggleTerm direction=float<cr>", "Float" },
    h = { "<cmd>lua _HSHELL_TOGGLE()<cr>", "Horizontal" },
    v = { "<cmd>lua _VSHELL_TOGGLE()<cr>", "Vertical" },
    r = { ":RnvimrToggle<CR>", "Ranger" },
  },
}, { prefix = "<leader>" })

```



#### hlsens


```lua 
use({ "kevinhwang91/nvim-hlslens" })
```

```lua 
require('hlslens').setup()

local kopts = {noremap = true, silent = true}

vim.api.nvim_set_keymap('n', 'n',
  [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts)
vim.api.nvim_set_keymap('n', 'N',
  [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts)
vim.api.nvim_set_keymap('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

vim.api.nvim_set_keymap('n', '<Leader>z', ':noh<CR>', kopts)
```


#### nvim-tree


```lua 
use("kyazdani42/nvim-tree.lua")
```
```lua 
local status_ok, nvim_tree = pcall(require, "nvim-tree")
if not status_ok then
  return
end

local config_status_ok, nvim_tree_config = pcall(require, "nvim-tree.config")
if not config_status_ok then
  return
end

local tree_cb = nvim_tree_config.nvim_tree_callback

nvim_tree.setup {
  update_focused_file = {
    enable = true,
    update_cwd = true,
  },
  renderer = {
    root_folder_modifier = ":t",
    icons = {
      glyphs = {
        default = "",
        symlink = "",
        folder = {
          arrow_open = "",
          arrow_closed = "",
          default = "",
          open = "",
          empty = "",
          empty_open = "",
          symlink = "",
          symlink_open = "",
        },
        git = {
          unstaged = "",
          staged = "S",
          unmerged = "",
          renamed = "➜",
          untracked = "U",
          deleted = "",
          ignored = "◌",
        },
      },
    },
  },
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    },
  },
  view = {
    width = 30,
    side = "left",
    mappings = {
      list = {
        { key = { "l", "<CR>", "o" }, cb = tree_cb "edit" },
        { key = "h", cb = tree_cb "close_node" },
        { key = "v", cb = tree_cb "vsplit" },
      },
    },
  },
}

```


#### pretty-fold


```lua 
use({
  "anuvyklack/pretty-fold.nvim",
  config = function()
    require("user.plug-setting.pretty-fold")
  end,
  ft_setup = { "neorg", {} },
})
```
```lua 
local pretty_fold = require('pretty-fold')

pretty_fold.setup {
  sections = {
    left = {
      '━ ', function() return string.rep('+', vim.v.foldlevel) end, ' ━┫', 'content', '┣'
    },
    right = {
      '┫ ', 'number_of_folded_lines', ': ', 'percentage', ' ┣━━',
    }
  },
  fill_char = '━',
  -- fill_char = '•',

  remove_fold_markers = true,

  -- Keep the indentation of the content of the fold string.
  keep_indentation = true,

  -- Possible values:
  -- "delete" : Delete all comment signs from the fold string.
  -- "spaces" : Replace all comment signs with equal number of spaces.
  -- false    : Do nothing with comment signs.
  process_comment_signs = 'spaces',

  -- Comment signs additional to the value of `&commentstring` option.
  comment_signs = {},

  -- List of patterns that will be removed from content foldtext section.
  stop_words = {
    '@brief%s*', -- (for C++) Remove '@brief' and all spaces after.
  },

  add_close_pattern = true, -- true, 'last_line' or false

  matchup_patterns = {
    {  '{', '}' },
    { '%(', ')' }, -- % to escape lua pattern char
    { '%[', ']' }, -- % to escape lua pattern char
  },

  -- ft_ignore = { },
}

return pretty_fold

```


#### autosave


```lua 
use("907th/vim-auto-save")
```
```lua  
vim.g.auto_save = 1
-- vim.g.auto_save_events = {"InsertLeave", "TextChangedI", "CompleteDone", "TextChanged"}
vim.g.auto_save_silent = 1

vim.cmd [[
roup ft_auto_saves
u!
u FileType markdown let b:auto_save = 1
u FileType python let b:auto_save = 1
u FileType julia let b:auto_save = 0
u FileType go let b:auto_save = 1
u FileType css let b:auto_save = 1
u FileType json let b:auto_save = 1
u FileType java let b:auto_save = 1
u FileType html let b:auto_save = 1
u FileType r let b:auto_save = 1
u FileType scss let b:auto_save = 1 
u FileType sql let b:auto_save = 1  
u FileType sh let b:auto_save = 1  
u FileType dockerfile let b:auto_save = 1  
u FileType javascript let b:auto_save = 1  
u FileType vue let b:auto_save = 0
u FileType vim let b:auto_save = 1
u FileType rmd let b:auto_save = 1
u FileType tex let b:auto_save = 1
u FileType lua let b:auto_save = 1
u FileType md let b:auto_save = 1
u FileType vimwiki let b:auto_save = 1
u BufWinEnter plugins.lua let b:auto_save = 0

roup END

```


#### ranger


```lua 
use({ "kevinhwang91/rnvimr", run = "make sync" }) -- ranger in vima
```
```lua 
-- Make Ranger rep ace Netrw and be the file explorer
vim.g.rnvimr_enable_ex = 1

-- Make Ranger to be hidden after picking a file
vim.g.rnvimr_enable_picker = 1

-- Disable a border for floating window
vim.g.rnvimr_draw_border = 0

-- Hide the files included in gitignore
vim.g.rnvimr_hide_gitignore = 1

-- Change the border's color
vim.g.rnvimr_border_attr = {
  fg = 14,
  bg = -1
}

-- Make Neovim wipe the buffers corresponding to the files deleted by Ranger
vim.g.rnvimr_enable_bw = 1

-- Add a shadow window, value is equal to 100 will disable shadow
vim.g.rnvimr_shadow_winblend = 70

-- Draw border with both
vim.g.rnvimr_ranger_cmd = { 'ranger', '--cmd=set draw_borders both' }

-- Link CursorLine into RnvimrNormal highlight in the Floating window
vim.cmd "highlight link RnvimrNormal CursorLine"


-- Map Rnvimr action
vim.g.rnvimr_action = {
  ['<C-t>'] = 'NvimEdit tabedit',
  ['<C-x>'] = 'NvimEdit split',
  ['<C-v>'] = 'NvimEdit vsplit',
  ['gw'] = 'JumpNvimCwd',
  ['yw'] = 'EmitRangerCwd'
}

-- Add views for Ranger to adapt the size of floating window
vim.g.rnvimr_ranger_views = {
  {
    minwidth = 90,
    ratio = {}
  },
  {
    minwidth = 50,
    maxwidth = 89,
    ratio = {1,1}
  },
  {
    maxwidth = 49,
    ratio = {1}
  }
}

vim.cmd[[ 
ustomize the initial layout
 g:rnvimr_layout = {
         \ 'relative': 'editor',
         \ 'width': float2nr(round(0.7 * &columns)),
         \ 'height': float2nr(round(0.7 * &lines)),
         \ 'col': float2nr(round(0.15 * &columns)),
         \ 'row': float2nr(round(0.15 * &lines)),
         \ 'style': 'minimal'
         \ }


-- Customize multiple preset layouts
-- '{}' represents the initial layout
vim.g.rnvimr_presets = {
  {
    width = 0.600,
    height = 0.600
  },
  { width = 0.800,
    height = 0.800
  },
  {
    width = 0.950,
    height = 0.950
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0,
    row = 0
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0,
    row = 0.5
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0.5,
    row = 0
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0.5,
    row =  0.5
  },
  {
    width = 0.500,
    height = 1.000,
    col = 0,
    row = 0
  },
  {
    width = 0.500,
    height = 1.000,
    col = 0.5,
    row = 0
  },
  {
    width = 1.000,
    height = 0.500,
    col = 0,
    row = 0
  },
  {
    width = 1.000,
    height = 0.500,
    col = 0,
    row = 0.5
  }
}

-- Fullscreen for initial layout
-- let g:rnvimr_layout = {
--            \ relative = editor =
--            \ width = &columns,
--            \ height = &lines - 2,
--            \ col = 0,
--            \ row = 0,
--            \ 'style': 'minimal'
--            \ }
--
-- Only use initial preset layout
-- let g:rnvimr_presets = [{}]
-- nmap <space>r :RnvimrToggle<CR>
vim.g.rnvimr_vanilla = 1
```


#### impatient


```lua 
use("lewis6991/impatient.nvim") -- suppose to speed up lua load times
```
```lua 
local status_ok, impatient = pcall(require, "impatient")
if not status_ok then
  return
end

impatient.enable_profile()
```



#### whichkey


```lua 

```
```lua 

```


### Note taking & Organizational Plugins


```lua
use("jbyuki/nabla.nvim") -- neat looking math pluging
use("edluffy/hologram.nvim")
use("gioele/vim-autoswap")

use("dhruvasagar/vim-table-mode")
use("davidgranstrom/nvim-markdown-preview")
use("chrisbra/csv.vim")
use("godlygeek/tabular")
```


#### Neorg


```lua 
use({
  "nvim-neorg/neorg",
  -- "tamton-aquib/neorg",
  -- tag = "0.0.12",
  run = ":Neorg sync-parsers",
  -- ft = "norg",
  branch = "main",
  -- branch = "code-execution",
  -- commit = "4c0a5b1e49577fba0bd61ea18cf130d9545d2d52",
  config = function()
    require("user.plug-setting.neorg")
    -- vim.cmd "NeorgStart silent=true"
  end,
  -- cmd = { 'Neorg' },
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-neorg/neorg-telescope",
    "esquires/neorg-gtd-project-tags",
    "danymat/neorg-gtd-things",
    "max397574/neorg-contexts",
    "max397574/neorg-kanban",
    "folke/zen-mode.nvim",
    "Pocco81/TrueZen.nvim",
  },
})
```
```lua 
local neorg = require("neorg")

neorg.setup({
  ensure_installed = { "norg" },
  highlight = { enable = true },
  requires = { "core.export.markdown" },
  load = {
    ["core.defaults"] = {},
    ["core.integrations.treesitter"] = {
      config = {
        norg = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg",
          files = { "src/parser.c", "src/scanner.cc" },
          branch = "main",
        },
        norg_meta = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
          files = { "src/parser.c" },
          branch = "main",
        },
        norg_table = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg-table",
          files = { "src/parser.c" },
          branch = "main",
        },
      },
    },
    ["core.norg.qol.toc"] = {},

    -- ["core.norg.esupports.metagen"] = {
    -- 	config = {
    -- 		type = "auto",
    -- 	},
    -- },
    ["core.keybinds"] = {
      config = {
        hook = function(keybinds)
          local status_ok, which_key = pcall(require, "which-key")
          if not status_ok then
            return
          end
          which_key.register({
            t = {
              name = "+Gtd",
              c = "Capture",
              e = "Edit",
              v = "Views",
            },
            -- t = {
            --   name = "GTD Base",
            --   c = { "<Cmd>Neorg keybind norg core.gtd.base.capture<CR>", "Capture"},
            --   v = { "<Cmd>Neorg keybind norg core.gtd.base.views<CR>", "Views"},
            --   e = { "<Cmd>Neorg keybind norg core.gtd.base.edit<CR>", "Edit"},
            -- },
            m = {
              name = "Neorg",
              h = { ":Neorg mode traverse-heading<CR>", "Traverse Heading" },
              n = { ":Neorg mode norg<CR>", "Neorg Mode" },
              t = { "<Cmd>Neorg keybind norg core.norg.concealer.toggle-markup<CR>", "Toggle Markup" },
            },
            -- n = {
            --   name = "Note",
            -- },
          }, { prefix = "," }, { mode = "n" })
          which_key.register({
            name = "Note",
            -- l = { "<Cmd>Neorg keybind norg core.integrations.telescope.find_linkable<CR>", "Find Linkable"},
            p = { ":Neorg presenter start<cr>", "Start Presentation" },
            n = { "<Cmd>Neorg keybind norg core.norg.dirman.new.note<CR>", "New Note" },
            j = { ":Neorg journal today<cr>", "Today's Journal" },
          }, { prefix = "<Space>" })
          -- which_key.register({
          --     name = "Note",
          --     l = { "<Cmd>core.integrations.telescope.insert_link<CR>", "Find Linkable"},
          -- },
          -- { mode = "v" }
          -- )
          which_key.register({
            -- name = "Note",
            -- ["<C-L>"] = { "<Cmd>Neorg keybind norg core.integrations.telescope.insert_link<CR>", "Insert Link"},
            ["<C-s>"] = { ":w<CR>", "Save" },
            -- not sure if I want to do these... cause they conflict with window movement
            ["<C-j>"] = {
              "<Cmd>Neorg keybind norg core.integrations.treesitter.next.heading<CR>",
              "Next Heading",
            },
            ["<C-k>"] = {
              "<Cmd>Neorg keybind norg core.integrations.treesitter.previous.heading<CR>",
              "Next Heading",
            },
            -- ["<TAB>"] = { ":Neorg keybind norg core.promo.promote<CR>" , "Promote" },
            -- ["<S-TAB>"] = { ":Neorg keybind norg core.promo.demote<CR>" , "Demote" }
            -- M = { "0i|<esc>", "Marker" }
          })
          which_key.register({
            name = "Note",
            t = {
              name = "Neorg Task Motions",
              r = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_recurring<CR>",
                "Task Recurring",
              },
              c = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_cancelled<CR>",
                "Task Cancelled",
              },
              i = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_important<CR>",
                "Task Important",
              },
              h = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_on_hold<CR>",
                "Task On Hold",
              },
              p = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_pending<CR>",
                "Task Pending",
              },
              u = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_undone<CR>",
                "Task Pending",
              },
              d = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_done<CR>", "Task Done" },
              C = { "<Cmd>Neorg gtd capture<CR>", "Capture" },
              e = { "<Cmd>Neorg gtd edit<CR>", "Edit" },
              v = { "<Cmd>Neorg gtd views<CR>", "Views" },
            },
          }, { prefix = "g" })
          keybinds.unmap("norg", "n", "<C-s>")
        end,
      },
    },
    ["core.norg.journal"] = {},
    ["core.integrations.telescope"] = {},
    ["core.gtd.base"] = {
      config = {
        workspace = "home",
        default_lists = {
          inbox = "inbox.norg",
        },
        syntax = {
          context = "#contexts",
          start = "#time.start",
          due = "#time.due",
          waiting = "#waiting.for",
        },
        exclude = {
          "wiki",
        },
      },
    },
    ["external.gtd-project-tags"] = {},
    ["external.context"] = {},
    ["core.tangle"] = {},
    ["core.norg.manoeuvre"] = {},
    ["core.export"] = { config = {} },
    -- ["core.execute"] = {},
    ["core.export.markdown"] = {
      config = {
        extensions = "all",
      },
    },
    ["core.presenter"] = {
      config = {
        zen_mode = "zen-mode",
        -- zen_mode = "truezen",
      },
    },
    ["external.kanban"] = {
      config = {
        task_states = {
          "undone",
          "done",
          "pending",
          "cancelled",
          "uncertain",
          "urgent",
          "recurring",
          "on_hold",
        },
      },
    },
    ["core.norg.concealer"] = {},
    ["core.norg.completion"] = {
      config = {
        engine = "nvim-cmp", -- we current support nvim-compe and nvim-cmp only
      },
    },
    ["core.norg.dirman"] = {
      config = {
        workspaces = {
          home = "~/vimwiki/home",
          work = "~/vimwiki/work",
        },
        default_workspace = "work",
      },
    },
  },
})

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  name = "Note",
  n = { ":Neorg workspace home<cr>", "Find Linkable" },
}, { prefix = "<Space>" })

return neorg
```

#### Vimwiki


```lua 
use("vimwiki/vimwiki")
```

```lua 
vim.cmd "autocmd BufRead,BufNewFile *.wiki set filetype=vimwik"
-- vim.cmd "autocmd BufRead,BufNewFile diary.md :CalendarVR"
vim.cmd "autocmd BufReadPre diary.md :VimwikiDiaryGenerateLinks"
-- vim.cmd "autocmd BufReadPre index.md :VimwikiGenerateLinks"

vim.g.vimwiki_ext2syntax = {
  [".Rmd"] = "markdown",
  [".rmd"] = "markdown",
  [".markdown"] = "markdown",
  [".mdown"] = "markdown",
  [".md"] = "markdown"
}
vim.g.vimwiki_list = {
  {
    path = '~/vimwiki',
    syntax = 'markdown',
    ext = '.md',
    auto_toc = 1,
    auto_tags = 1,
    links_space_char = "_",
    auto_diary_index = 1,
    diary_caption_level = 2,
  },
  {
    path = '~/vimwiki/devops',
    syntax = 'markdown',
    ext = '.md',
    auto_toc = 1,
    auto_tags = 1,
    links_space_char = "_",
  },
  {
    path = '~/vimwiki/code',
    syntax = 'markdown',
    ext = '.md',
    auto_toc = 1,
    auto_tags = 1,
    links_space_char = "_",
  },
  {
    path = '~/vimwiki/linux',
    syntax = 'markdown',
    ext = '.md',
    auto_toc = 1,
    auto_tags = 1,
    links_space_char = "_",
  },
  {
    path = '~/vimwiki/random',
    syntax = 'markdown',
    ext = '.md',
    auto_toc = 1,
    auto_tags = 1,
    links_space_char = "_",
  }


}
vim.g.vim_markdown_math = 1
vim.g.vim_markdown_json_frontmatter = 1
vim.g.vim_markdown_strikethrough = 1
vim.g.vim_markdown_new_list_item_indent = 2
vim.g.vimwiki_global_ext = 0
vim.g.vimwiki_table_mappings = 0
vim.g.vimwiki_listsyms = '✗○◐●✓'
vim.g.vimwiki_use_calendar = 1
vim.g.vimwiki_auto_header = 1
vim.g.vimwiki_folding = 'custom'

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  W = {
    name = "VimWiki",
    d = { "<Plug>VimwikiIncrementListItem", "Incriment Completion Level"},
    u = { "<Plug>VimwikiDecrementListItem", "Incriment Completion Level"},
    t = { "<Plug>VimwikiToggleListItem", "Toggle Checkbox"},
    f = { '<cmd>lua require("telescope.builtin").find_files({cwd = "~/vimwiki"})<CR>', "Find Wiki" },
    D = { "<cmd>VimwikiDiaryIndex<cr>", "Vimwiki Diary" },
    w = { "<cmd>VimwikiIndex<CR>", "Vimwiki Main" },
    n = { "<cmd>VimwikiMakeDiaryNote<CR>", "Daily Note"},
    N = { "<cmd>VimwikiMakeTomorrowDiaryNote<CR>", "Tomorrows Note"},
  },
},
  { prefix = "<leader>" }
)

vim.g.vimwiki_filetypes = {'markdown', 'pandoc'}
```


#### Literate


```lua 
use("shoumodip/nvim-literate")
```
```lua 
local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  e = {
    c = { ":lua require'literate'.Comment()<CR>", "Comment"},
    t = { ":lua require'literate'.Tangle()<CR>", "Tangle" },
    s = { ":lua require'literate'.Edit()<CR>", "Edit" },
    q = { ":lua require'literate'.EditClose()<CR>", "Close Edit Window" },
  },
},
  { prefix = "<leader>" }
)
```


#### Zen


```lua 
use("folke/zen-mode.nvim") 
```

```lua 
local zen = require("zen-mode")
zen.setup {
  window = {
    backdrop = 0.95, -- shade the backdrop of the Zen window. Set to 1 to keep the same as Normal
    -- height and width can be:
    -- * an absolute number of cells when > 1
    -- * a percentage of the width / height of the editor when <= 1
    -- * a function that returns the width or the height
    width = 120, -- width of the Zen window
    height = 1, -- height of the Zen window
    -- by default, no options are changed for the Zen window
    -- uncomment any of the options below, or add other vim.wo options you want to apply
    options = {
      -- signcolumn = "no", -- disable signcolumn
      number = false, -- disable number column
      relativenumber = false, -- disable relative numbers
      cursorline = false, -- disable cursorline
      -- cursorcolumn = false, -- disable cursor column
      foldcolumn = "0", -- disable fold column
      -- list = false, -- disable whitespace characters
    },
  },
  plugins = {
    -- disable some global vim options (vim.o...)
    -- comment the lines to not apply the options
    options = {
      enabled = true,
      ruler = false, -- disables the ruler text in the cmd line area
      showcmd = false, -- disables the command in the last line of the screen
    },
    twilight = { enabled = true }, -- enable to start Twilight when zen mode opens
    gitsigns = { enabled = false }, -- disables git signs
    tmux = { enabled = false }, -- disables the tmux statusline
    -- this will change the font size on kitty when in zen mode
    -- to make this work, you need to set the following kitty options:
    -- - allow_remote_control socket-only
    -- - listen_on unix:/tmp/kitty
    kitty = {
      enabled = false,
      font = "+4", -- font size increment
    },
  },

  -- callback where you can add custom code when the Zen window opens
  on_open = function(win)
  end,
  -- callback where you can add custom code when the Zen window closes
  on_close = function()
  end,
}

return zen

```


#### Mind


```lua 
use("phaazon/mind.nvim")
```

```lua 
require("mind").setup({
  edit = {
    data_extension = ".norg",
    data_header = "* %s",
  },
  persistence = {
    state_path = "~/vimwiki/mind.json",
    data_dir = "~/vimwiki",
  },
})
```


#### Pandoc


```lua 
use("vim-pandoc/vim-pandoc-syntax")
```

```lua 
vim.g["pandoc#syntax#codeblocks#embeds#langs"] = {"python", "julia", "bash=sh", "json=javascript", "javascript", "clojure", "zsh=sh", "dockerfile"}
vim.g["pandoc#syntax#conceal#urls"] = 1
-- vim.g["pandoc#folding#mode"] = {'manual'}
vim.g["pandoc#folding#fdc"] = 0

```


#### Markdown


```lua 
use("mzlogin/vim-markdown-toc")
```

```lua 
vim.g.vim_markdown_conceal = 1
vim.o.conceallevel=2
vim.g.vim_markdown_conceal_code_blocks = 1
vim.g.vim_markdown_fenced_languages = { 'julia','julia=md', 'python', 'bash=sh', 'viml=vim', 'javascript=js', 'zsh', 'bash=sh'}
vim.g.markdown_folding = 1

vim.o.foldmethod = "expr"
vim.cmd "set foldexpr=nvim_treesitter#foldexpr()"
vim.cmd "autocmd FileType markdown lua require('literate')"
vim.cmd "autocmd FileType vimwiki lua require('literate')"
```


#### knap


```lua 
use "frabjous/knap"
```
```lua 
-- set shorter name for keymap function
local kmap = vim.keymap.set

-- F5 processes the document once, and refreshes the view
kmap('i','<F5>', function() require("knap").process_once() end)
kmap('v','<F5>', function() require("knap").process_once() end)
kmap('n','<F5>', function() require("knap").process_once() end)

-- F6 closes the viewer application, and allows settings to be reset
kmap('i','<F6>', function() require("knap").launch_viewer() end)
kmap('v','<F6>', function() require("knap").launch_viewer() end)
kmap('n','<F6>', function() require("knap").launch_viewer() end)

-- F7 toggles the auto-processing on and off
kmap('i','<F7>', function() require("knap").toggle_autopreviewing() end)
kmap('v','<F7>', function() require("knap").toggle_autopreviewing() end)
kmap('n','<F7>', function() require("knap").toggle_autopreviewing() end)

-- F8 invokes a SyncTeX forward search, or similar, where appropriate
kmap('i','<F8>', function() require("knap").forward_jump() end)
kmap('v','<F8>', function() require("knap").forward_jump() end)
kmap('n','<F8>', function() require("knap").forward_jump() end)

local gknapsettings = {
  texoutputext = "pdf",
  textopdfforwardjump = "zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%",
  textopdfviewerlaunch = "zathura --synctex-editor-command 'nvim --headless -es --cmd \"lua require('\"'\"'knaphelper'\"'\"').relayjump('\"'\"'%servername%'\"'\"','\"'\"'%{input}'\"'\"',%{line},0)\"' %outputfile%",
  textopdfviewerrefresh = "none"
}

vim.g.knap_settings = gknapsettings

-- vim.cmd[[ 
-- let g:knap_settings = {
--     \ "textopdfviewerlaunch": "zathura --synctex-editor-command 'nvim --headless -es --cmd \"lua require('\"'\"'knaphelper'\"'\"').relayjump('\"'\"'%servername%'\"'\"','\"'\"'%{input}'\"'\"',%{line},0)\"' %outputfile%",
--     \ "textopdfviewerrefresh": "none",
--     \ "textopdfforwardjump": "zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%"
-- \ }
-- ]]
-- local gknapsettings = {
--     texoutputext = "pdf",
--     textopdf = "pdflatex -synctex=1 -halt-on-error -interaction=batchmode %docroot%",
--     textopdfviewerlaunch = "mupdf %outputfile%",
--     textopdfviewerrefresh = "kill -HUP %pid%"
-- }
-- vim.g.knap_settings = gknapsettings
```

#### project


```lua 
use("ahmedkhalf/project.nvim")
```

```lua 
local status_ok, project = pcall(require, "project_nvim")
if not status_ok then
  return
end
project.setup({
  ---@usage set to false to disable project.nvim.
  --- This is on by default since it's currently the expected behavior.
  active = true,

  on_config_done = nil,

  ---@usage set to true to disable setting the current-woriking directory
  --- Manual mode doesn't automatically change your root directory, so you have
  --- the option to manually do so using `:ProjectRoot` command.
  manual_mode = false,

  ---@usage Methods of detecting the root directory
  --- Allowed values: **"lsp"** uses the native neovim lsp
  --- **"pattern"** uses vim-rooter like glob pattern matching. Here
  --- order matters: if one is not detected, the other is used as fallback. You
  --- can also delete or rearangne the detection methods.
  -- detection_methods = { "lsp", "pattern" }, -- NOTE: lsp detection will get annoying with multiple langs in one project
  detection_methods = { "pattern" },

  ---@usage patterns used to detect root dir, when **"pattern"** is in detection_methods
  patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", "deps.edn", "Project.toml", "pyproject.toml" },

  ---@ Show hidden files in telescope when searching for files in a project
  show_hidden = false,

  ---@usage When set to false, you will get a message when project.nvim changes your directory.
  -- When set to false, you will get a message when project.nvim changes your directory.
  silent_chdir = true,

  ---@usage list of lsp client names to ignore when using **lsp** detection. eg: { "efm", ... }
  ignore_lsp = {},

  ---@type string
  ---@usage path to store the project history for use in telescope
  datapath = vim.fn.stdpath("data"),
})

local tele_status_ok, telescope = pcall(require, "telescope")
if not tele_status_ok then
  return
end

telescope.load_extension('projects')
```


#### Calendar


```lua 
use("itchyny/calendar.vim")
```

```lua 
vim.g.calendar_google_calendar = 1
vim.g.calendar_google_task = 1
vim.cmd "source $HOME/.config/shell/private/calendar-creds.vim"
```


### Coding Plugins


```lua 
use("windwp/nvim-ts-autotag")
use("jpalardy/vim-slime") -- allow vim to send julia / python commands to the repl
use({ "usmcamp0811/magma-nvim", run = ":UpdateRemotePlugins", branch = "fix-output" })
use("clojure-vim/vim-jack-in")
use("lervag/vimtex") -- for writing latex
use({ "hasundue/vim-pluto", requires = { "vim-denops/denops.vim" } })
use("ii14/neorepl.nvim")

use("aklt/plantuml-syntax")
use("lukas-reineke/indent-blankline.nvim")

use({
  "weirongxu/plantuml-previewer.vim",
  requires = { 
    { "tyru/open-browser.vim", opt = false },
    { "aklt/plantuml-syntax", opt = false } 
  },
})
use("b0o/SchemaStore.nvim")
use({
  "https://gitlab.com/usmcamp0811/nvim-julia-autotest",
  config = function()
    require("julia-autotest").setup()
  end,
})
use("David-Kunz/markid") -- better function syntax higlighting
```

#### Conjure


Mostly for Clojure, but works with Julia and a few other languages. I like it a lot 
but it doesn't support connecting to remote/external REPLs in Julia so it has some 
limitations.

```lua 
use("Olical/conjure")
use("Olical/aniseed")
```

```lua 
local function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

-- looks for the Project.toml to use for the test
local function julia_project_dir()
  bufnr = vim.fn.bufnr('%')
  -- ns_id = vim.api.nvim_create_namespace('julia-testing')
  local root_dir
  for dir in vim.fs.parents(vim.api.nvim_buf_get_name(bufnr)) do
    if file_exists(dir .. "/Project.toml") == true then
      root_dir = dir
      break
    end
  end

  if root_dir then
    -- print("Found julia project at", root_dir)
    return root_dir
  end
end


local function make_conjure_command()
  local root = julia_project_dir()
  if root == nil then
    root = ""
  else
    root = "--project=" .. root
  end
  vim.g["conjure#client#julia#stdio#command"] = "jupyter console --kernel julia-1.8 -f /tmp/julia.json"
end
vim.g["conjure#filetypes"] = { "fennel", "clojure", "julia", "jl", "python", "py", "norg" }
```


#### Comment


```lua 
use({
  "numToStr/Comment.nvim",
  --tag = "v0.6.1",
  --branch = "master",
})
```

```lua 
local status_ok, comment = pcall(require, "Comment")
if not status_ok then
  return
end

comment.setup({
  pre_hook = function(ctx)
    local U = require("Comment.utils")

    local location = nil
    if ctx.ctype == U.ctype.block then
      location = require("ts_context_commentstring.utils").get_cursor_location()
    elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
      location = require("ts_context_commentstring.utils").get_visual_start_location()
    end

    return require("ts_context_commentstring.internal").calculate_commentstring({
      key = ctx.ctype == U.ctype.line and "__default" or "__multiline",
      location = location,
    })
  end,
})

local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  ["<BS>"] = { "<Plug>(comment_toggle_linewise_current)<cr>", "Comment Toggle" },
  T = { ":r! date +'\\%H:\\%M - '<CR>A", "Insert Current Time" },
})

which_key.register({
  ["<BS>"] = { "<Plug>(comment_toggle_linewise_visual)<cr>", "Comment Toggle" },
  p = { '"_dP', "Paste without overwriting the register" },
}, { mode = "v" })
```




#### Code Window


```lua 
use({
  "gorbit99/codewindow.nvim",
  config = function()
    local codewindow = require("codewindow")
    codewindow.setup()
    codewindow.apply_default_keybinds()
  end,
})
```

```lua 
local M = {}

local config = {
  minimap_width = 20,
  width_multiplier = 4,
  use_lsp = true,
  use_treesitter = true,
  exclude_filetypes = {},
  z_index = 1,
}

function M.get()
  return config
end

function M.setup(new_config)
  for k, v in pairs(new_config) do
    config[k] = v
  end
end

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end
which_key.register({
  w = { ":lua require('codewindow').toggle_minimap()<CR>", "Toggle Code Window" },
}, { mode = "n", silent = true, noremap = true, buffer = bufnr, prefix = "<leader>" })
return M
```


#### Navic


```lua 
use({
  "SmiteshP/nvim-navic",
  requires = "neovim/nvim-lspconfig",
})
```

```lua 
local navic = require("nvim-navic")

navic.setup {
  icons = {
    File          = " ",
    Module        = " ",
    Namespace     = " ",
    Package       = " ",
    Class         = " ",
    Method        = " ",
    Property      = " ",
    Field         = " ",
    Constructor   = " ",
    Enum          = "練",
    Interface     = "練",
    Function      = " ",
    Variable      = " ",
    Constant      = " ",
    String        = " ",
    Number        = " ",
    Boolean       = "◩ ",
    Array         = " ",
    Object        = " ",
    Key           = " ",
    Null          = "ﳠ ",
    EnumMember    = " ",
    Struct        = " ",
    Event         = " ",
    Operator      = " ",
    TypeParameter = " ",
  },
  highlight = false,
  separator = " > ",
  depth_limit = 0,
  depth_limit_indicator = "..",
  safe_output = true
}
```





### Git Plugins


```lua 
use({
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup()
    require("scrollbar.handlers.gitsigns").setup()
  end,
}) 
use({ "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim" })
```


### Treesitter & LSP


```lua 
use({
  "nvim-treesitter/nvim-treesitter-textobjects",
  run = ":TSUpdate",
})
use({
  "RRethy/nvim-treesitter-textsubjects",
})
use("nvim-treesitter/playground")
use("https://github.com/JoosepAlviste/nvim-ts-context-commentstring.git")
use("neovim/nvim-lspconfig") -- enable LSP
use("williamboman/nvim-lsp-installer") -- simple to use language server installer
use("tamago324/nlsp-settings.nvim")
-- use "lukas-reineke/lsp-format.nvim"
use("jose-elias-alvarez/null-ls.nvim") -- for formatters and linters
use("https://git.sr.ht/~whynothugo/lsp_lines.nvim")

use("williamboman/mason.nvim")
use("williamboman/mason-lspconfig.nvim")
use({
  "folke/trouble.nvim",
  requires = "kyazdani42/nvim-web-devicons",
  config = function()
    require("trouble").setup({
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    })
  end,
})
```


#### Treesitter


```lua 
use({
  "nvim-treesitter/nvim-treesitter",
  run = ":TSUpdate",
  markid = { enable = true },
})
```

```lua 
local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then return
end

local status_ok, markid = pcall(require, "markid")
if not status_ok then
  return
end

markid.colors = {
  dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
  bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#98fc03" },
  medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
}

markid.queries = {
  default = '(identifier) @markid',
  javascript = [[
     (identifier) @markid
     (property_identifier) @markid
     (shorthand_property_identifier_pattern) @markid
   ]]
}
markid.queries.typescript = markid.queries.javascript

parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

-- This has some issue on unsteup systems.. its not installing correctly.. but it also doesn't seem necesary
-- parser_configs.markdown = {
--   install_info = {
--     url = "https://github.com/ikatyang/tree-sitter-markdown",
--     files = { "src/parser.c", "src/scanner.cc" },
--   },
--   filetype = { "vimwiki", "markdown" },
-- }

configs.setup({
  ensure_installed = "all", -- one of "all" or a list of languages
  ignore_install = { "" }, -- List of parsers to ignore installing
  highlight = {
    enable = true, -- false will disable the whole extension
    disable = { "css" }, -- list of language that will be disabled
    additional_vim_regex_highlighting = { "org", "norg" },
  },
  autopairs = {
    enable = true,
  },
  autotag = {
    enable = true,
    filetypes = {
      "html",
      "javascript",
      "typescript",
      "javascriptreact",
      "typescriptreact",
      "svelte",
      "vue",
      "tsx",
      "jsx",
      "rescript",
      "xml",
      "php",
      "markdown",
      "glimmer",
      "handlebars",
      "hbs",
      "julia",
      "norg",
    },
  },
  indent = { enable = true, disable = { "python", "css" } },
  parser_configs = parser_configs,
  textsubjects = {
    enable = true,
    prev_selection = ",", -- (Optional) keymap to select the previous selection
    keymaps = {
      ["."] = "textsubjects-smart",
      [";"] = "textsubjects-container-outer",
      ["i;"] = "textsubjects-container-inner",
    },
  },
  rainbow = {
    enable = true,
    extended_mode = true
  },
  markid = {
    enable = true,
    colors = markid.colors.bright,
    queries = markid.queries,
    is_supported = function(lang)
      local queries = configs.get_module("markid").queries
      return pcall(vim.treesitter.parse_query, lang, queries[lang] or queries['default'])
    end
  },
  textobjects = {
    select = {
      enable = true,

      -- Automatically jump forward to textobj, similar to targets.vim
      lookahead = true,

      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ae"] = "@call.outer",
        ["ie"] = "@call.inner",
        ["ib"] = "@code",
        ["ag"] = "@def",
        -- You can optionally set descriptions to the mappings (used in the desc parameter of
        -- nvim_buf_set_keymap) which plugins like which-key display
        ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
      },
      -- You can choose the select mode (default is charwise 'v')
      --
      -- Can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * method: eg 'v' or 'o'
      -- and should return the mode ('v', 'V', or '<c-v>') or a table
      -- mapping query_strings to modes.
      selection_modes = {
        ['@parameter.outer'] = 'v', -- charwise
        ['@function.outer'] = 'V', -- linewise
        ['@class.outer'] = '<c-v>', -- blockwise
        ['@call.outer'] = 'v', -- charwise
      },
      -- If you set this to `true` (default is `false`) then any textobject is
      -- extended to include preceding or succeeding whitespace. Succeeding
      -- whitespace has priority in order to act similarly to eg the built-in
      -- `ap`.
      --
      -- Can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * selection_mode: eg 'v'
      -- and should return true of false
      include_surrounding_whitespace = true,
    },
  },
})
```


### Telescope


```lua 
use("nvim-telescope/telescope.nvim")
use("nvim-telescope/telescope-symbols.nvim")
use("nvim-telescope/telescope-media-files.nvim")
```

```lua 
local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
  return
end

local actions = require "telescope.actions"

telescope.setup {
  defaults = {

    prompt_prefix = " ",
    selection_caret = " ",
    path_display = { "smart" },

    mappings = {
      i = {
        ["<C-n>"] = actions.cycle_history_next,
        ["<C-p>"] = actions.cycle_history_prev,

        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,

        ["<C-c>"] = actions.close,

        ["<Down>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,

        ["<CR>"] = actions.select_default,
        ["<C-x>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["<C-t>"] = actions.select_tab,

        ["<C-u>"] = actions.preview_scrolling_up,
        ["<C-d>"] = actions.preview_scrolling_down,

        ["<PageUp>"] = actions.results_scrolling_up,
        ["<PageDown>"] = actions.results_scrolling_down,

        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
        ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
        ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        ["<C-l>"] = actions.complete_tag,
        ["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
      },

      n = {
        ["<esc>"] = actions.close,
        ["<CR>"] = actions.select_default,
        ["<C-x>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["<C-t>"] = actions.select_tab,

        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
        ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
        ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

        ["j"] = actions.move_selection_next,
        ["k"] = actions.move_selection_previous,
        ["H"] = actions.move_to_top,
        ["M"] = actions.move_to_middle,
        ["L"] = actions.move_to_bottom,

        ["<Down>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,
        ["gg"] = actions.move_to_top,
        ["G"] = actions.move_to_bottom,

        ["<C-u>"] = actions.preview_scrolling_up,
        ["<C-d>"] = actions.preview_scrolling_down,

        ["<PageUp>"] = actions.results_scrolling_up,
        ["<PageDown>"] = actions.results_scrolling_down,

        ["?"] = actions.which_key,
      },
    },
  },
  pickers = {
    -- Default configuration for builtin pickers goes here:
    -- picker_name = {
    --   picker_config_key = value,
    --   ...
    -- }
    -- Now the picker_config_key will be applied every time you call this
    -- builtin picker
  },
  extensions = {
    -- Your extension configuration goes here:
    -- extension_name = {
    --   extension_config_key = value,
    -- }
    -- please take a look at the readme of the extension you want to configure
  },
}



local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  s = {
    name = "Search",
    b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
    c = { "<cmd>Telescope colorscheme<cr>", "Colorscheme" },
    h = { "<cmd>Telescope help_tags<cr>", "Find Help" },
    M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
    r = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
    R = { "<cmd>Telescope registers<cr>", "Registers" },
    k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
    C = { "<cmd>Telescope commands<cr>", "Commands" },
  },
},
  { prefix = "<leader>" }
)
```


### Auto Completion / Snippets


```lua 
use("hrsh7th/cmp-nvim-lsp")
use("hrsh7th/cmp-buffer")
use("hrsh7th/cmp-path")
use("hrsh7th/cmp-copilot")
use("uga-rosa/cmp-dynamic")
use("tamago324/cmp-zsh")
use("hrsh7th/cmp-calc")
use("f3fora/cmp-spell")
use("hrsh7th/cmp-cmdline")
use("hrsh7th/cmp-nvim-lsp-document-symbol")
use("saadparwaiz1/cmp_luasnip") -- snippet completions
use({ "PaterJason/cmp-conjure" })
use("L3MON4D3/LuaSnip") --snippet engine
use("rafamadriz/friendly-snippets") -- a bunch of snippets to use
use("honza/vim-snippets")

use({
  "glepnir/lspsaga.nvim",
  branch = "main",
  config = function()
    -- local saga = require("lspsaga")
    -- local config = require("user.plug-setting.lsp-saga")
    -- saga.init_lsp_saga(config)
    require("lspsaga").init_lsp_saga({})
  end,
})
```


#### cmp


```lua 
use({
  "hrsh7th/nvim-cmp",
  requires = {
    { "kdheepak/cmp-latex-symbols" },
  },
})
```

```lua 
local cmp_status_ok, cmp = pcall(require, "cmp")
if not cmp_status_ok then
  return
end

local snip_status_ok, luasnip = pcall(require, "luasnip")
if not snip_status_ok then
  return
end

-- require("luasnip/loaders/from_vscode").lazy_load()

local check_backspace = function()
  local col = vim.fn.col(".") - 1
  return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
end

--   פּ ﯟ   some other good icons
local kind_icons = {
  Text = "",
  Method = "m",
  Function = "",
  Constructor = "",
  Field = "",
  Variable = "",
  Class = "",
  Interface = "",
  Module = "",
  Property = "",
  Unit = "",
  Value = "",
  Enum = "",
  Keyword = "",
  Snippet = "",
  Color = "",
  File = "",
  Reference = "",
  Folder = "",
  EnumMember = "",
  Constant = "",
  Struct = "",
  Event = "",
  Operator = "",
  TypeParameter = "",
}
-- find more here: https://www.nerdfonts.com/cheat-sheet

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body) -- For `luasnip` users.
    end,
  },
  mapping = {
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
    ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
    ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
    ["<C-y>"] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
    ["<C-e>"] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    -- Accept currently selected item. If none selected, `select` first item.
    -- Set `select` to `false` to only confirm explicitly selected items.
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expandable() then
        luasnip.expand()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif check_backspace() then
        fallback()
      else
        fallback()
      end
    end, {
        "i",
        "s",
      }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, {
        "i",
        "s",
      }),
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      -- Kind icons
      vim_item.kind = string.format("%s", kind_icons[vim_item.kind])
      -- vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind) -- This concatonates the icons with the name of the item kind
      vim_item.menu = ({
        luasnip = "[Snippet]",
        buffer = "[Buffer]",
        path = "[Path]",
      })[entry.source.name]
      return vim_item
    end,
  },
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "conjure" },
    { name = "neorg" },
    { name = "dynamic" },
    { name = "latex_symbols" },
    { name = "orgmode" },
    { name = "path" },
    cmp.config.sources({
      { name = "nvim_lsp_document_symbol" },
    }, {
        { name = "buffer" },
      }),
    -- { name = "copilot" },
    { name = "nvim_lua" },
    { name = "calc" },
    { name = "buffer" },
    {
      name = "spell",
      option = {
        keep_all_entries = false,
        enable_in_context = function()
          return true
        end,
      },
    },
  },
  confirm_opts = {
    behavior = cmp.ConfirmBehavior.Replace,
    select = true,
  },
  window = {
    documentation = {
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    },
  },
})
cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = "path" },
  }, {
      { name = "cmdline" },
    }),
})

vim.cmd([[
y
ight! CmpItemAbbrDeprecated guibg=NONE gui=strikethrough guifg=#808080
e
ight! CmpItemAbbrMatch guibg=NONE guifg=#569CD6
ight! link CmpItemAbbrMatchFuzzy CmpItemAbbrMatch
ht blue
ight! CmpItemKindVariable guibg=NONE guifg=#9CDCFE
ight! link CmpItemKindInterface CmpItemKindVariable
ight! link CmpItemKindText CmpItemKindVariable
k
ight! CmpItemKindFunction guibg=NONE guifg=#C586C0
ight! link CmpItemKindMethod CmpItemKindFunction
nt
ight! CmpItemKindKeyword guibg=NONE guifg=#D4D4D4
ight! link CmpItemKindProperty CmpItemKindKeyword
ight! link CmpItemKindUnit CmpItemKindKeyword


local Date = require("cmp_dynamic.utils.date")

require("cmp_dynamic").setup({
  {
    label = "today",
    insertText = 1,
    cb = {
      function()
        return os.date("%Y/%m/%d")
      end,
    },
  },
  {
    label = "next Monday",
    insertText = 1,
    cb = {
      function()
        return Date.new():add_date(7):day(1):format("%Y/%m/%d")
      end,
    },
    resolve = true, -- default: false
  },
})


-- require("luasnip.loaders.from_lua").load({paths = "/home/mcamp/.config/nvim/lua/user/snippets"})
```


#### Auto Pairs


```lua 
use("windwp/nvim-autopairs")
```

```lua 
-- Setup nvim-cmp.
local status_ok, npairs = pcall(require, "nvim-autopairs")
if not status_ok then
  return
end
local Rule = require('nvim-autopairs.rule')


npairs.setup({
  check_ts = false,
  ts_config = {
    lua = { "string", "source" },
    javascript = { "string", "template_string" },
    norg = false,
  },
  disable_filetype = { "TelescopePrompt", "spectre_panel" },
  fast_wrap = {
    map = "<C-e>",
    chars = { "{", "[", "(", '"', "'" },
    -- pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
    pattern = [=[[%'%"%)%>%]%)%}%,]]=],
    offset = 0, -- Offset from pattern match
    end_key = "$",
    keys = "qwertyuiopzxcvbnmasdfghjkl",
    check_comma = true,
    highlight = "PmenuSel",
    highlight_grey = "LineNr",
  },
})


local cmp_autopairs = require("nvim-autopairs.completion.cmp")
local cmp_status_ok, cmp = pcall(require, "cmp")
if not cmp_status_ok then
  return
end
-- cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done({ map_char = { tex = "" } }))
local handlers = require('nvim-autopairs.completion.handlers')
cmp.event:on(
  'confirm_done',
  cmp_autopairs.on_confirm_done({
    filetypes = {
      -- "*" is a alias to all filetypes
      ["*"] = {
        ["("] = {
          kind = {
            cmp.lsp.CompletionItemKind.Function,
            cmp.lsp.CompletionItemKind.Method,
          },
          handler = handlers["*"]
        }
      },
      lua = {
        ["("] = {
          kind = {
            cmp.lsp.CompletionItemKind.Function,
            cmp.lsp.CompletionItemKind.Method
          },
          ---@param char string
          ---@param item item completion
          ---@param bufnr buffer number
          handler = function(char, item, bufnr)
            -- Your handler function. Inpect with print(vim.inspect{char, item, bufnr})
          end
        }
      },
      -- Disable for tex
      tex = false
    }
  })
)


npairs.add_rules({
  Rule("begin$", " end", "julia")
    :use_regex(true)
})


```


### Movement Plugins


```lua 
 use({
   "ggandor/flit.nvim",
   requires = { "ggandor/leap.nvim" },
 })
```


#### Leap


```lua 
use("ggandor/leap.nvim") --  better vertical jumping
```

```lua 
local leap = require("leap")

leap.set_default_keymaps()

vim.api.nvim_set_hl(0, "LeapMatch", { fg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelPrimary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelSecondary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapBackdrop", { fg = "gray" })

leap.setup({
  max_phase_one_targets = nil,
  highlight_unlabeled_phase_one_targets = false,
  max_highlighted_traversal_targets = 10,
  case_sensitive = false,
  equivalence_classes = { ' \t\r\n', },
  substitute_chars = {},
  -- safe_labels = { 's', 'f', 'n', 'u', 't', . . . },
  -- labels = { 's', 'f', 'n', 'j', 'k', . . . },
  special_keys = {
    repeat_search = '<enter>',
    next_phase_one_target = '<enter>',
    next_target = {'<enter>', ';'},
    prev_target = {'<tab>', ','},
    next_group = '<space>',
    prev_group = '<tab>',
    multi_accept = '<enter>',
    multi_revert = '<backspace>',
  }
})

require('flit').setup {
  keys = { f = 'f', F = 'F', t = 't', T = 'T' },
  -- A string like "nv", "nvo", "o", etc.
  labeled_modes = "v",
  multiline = true,
  -- Like `leap`s similar argument (call-specific overrides).
  -- E.g.: opts = { equivalence_classes = {} }
  opts = {}
}
```


### Miscellaneous Plugins 


```lua 
use("echasnovski/mini.nvim")
use("lambdalisue/suda.vim") -- runs `sudo` when needed
use("Eandrju/cellular-automaton.nvim")

use("petertriho/nvim-scrollbar")
use({
  "narutoxy/silicon.lua",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("silicon").setup({})
  end,
})
use({
  "chipsenkbeil/distant.nvim",
  config = function()
    require("distant").setup({
      -- Applies Chip's personal settings to every machine you connect to
      --
      -- 1. Ensures that distant servers terminate with no connections
      -- 2. Provides navigation bindings for remote directories
      -- 3. Provides keybinding to jump into a remote file's parent directory
      ["*"] = require("distant.settings").chip_default(),
    })
  end,
})

use("samjwill/nvim-unception")
```


### Theme's & Other Visual Enhancements


```lua 
use("Yazeed1s/minimal.nvim")
use("nvim-tree/nvim-web-devicons")
use("bluz71/vim-nightfly-guicolors")
use("bluz71/vim-moonfly-colors")
use("humanoid-colors/vim-humanoid-colorscheme")
use("lalitmee/cobalt2.nvim")
use("konosubakonoakua/synthwave84.nvim")
use("ellisonleao/gruvbox.nvim")
use({
  "catppuccin/nvim",
  as = "catppuccin",
  run = ":CatppuccinCompile",
})
use("lunarvim/darkplus.nvim")
use("joshdick/onedark.vim")
use("rebelot/kanagawa.nvim")
use("EdenEast/nightfox.nvim")

use("folke/lsp-colors.nvim")
use("p00f/nvim-ts-rainbow")
use({
  "gen740/SmoothCursor.nvim",
  config = function()
    require("smoothcursor").setup({
      autostart = true,
      cursor = "》", -- cursor shape (need nerd font)
      texthl = "SmoothCursor", -- highlight group, default is { bg = nil, fg = "#FFD400" }
      linehl = nil, -- highlight sub-cursor line like 'cursorline', "CursorLine" recommended
      type = "default", -- define cursor movement calculate function, "default" or "exp" (exponential).
      fancy = {
        enable = true, -- enable fancy mode
        head = { cursor = "❱", texthl = "SmoothCursor", linehl = nil },
        body = {
          { cursor = "", texthl = "SmoothCursorRed" },
          { cursor = "", texthl = "SmoothCursorOrange" },
          { cursor = "●", texthl = "SmoothCursorYellow" },
          { cursor = "●", texthl = "SmoothCursorGreen" },
          { cursor = "•", texthl = "SmoothCursorAqua" },
          { cursor = ".", texthl = "SmoothCursorBlue" },
          { cursor = ".", texthl = "SmoothCursorPurple" },
        },
        tail = { cursor = nil, texthl = "SmoothCursor" },
      },
      speed = 25, -- max is 100 to stick to your current position
      intervals = 35, -- tick interval
      priority = 10, -- set marker priority
      timeout = 3000, -- timout for animation
      threshold = 3, -- animate if threshold lines jump
      enabled_filetypes = nil, -- example: { "lua", "vim" }
      disabled_filetypes = nil,
      --{"mind", "TelescopePrompt", "NvimTree"}, -- this option will be skipped if enabled_filetypes is set. example: { "TelescopePrompt", "NvimTree" }
    })
  end,
})
```


#### Alpha


```lua 
use("goolord/alpha-nvim")
```

```lua 
local status_ok, alpha = pcall(require, "alpha")
if not status_ok then
  return
end

local dashboard = require("alpha.themes.dashboard")
dashboard.section.header.val = {
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⠻⢿⣷⣷⣷⣷⣷⣷⣷⣷⣧⣤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢂⣀⠀⡀⠀⠀⠀⠀⠀⠀⠈⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⢀⡍⢛⣷⣿⡆⠀⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣿⣿⣿⣆⠘⠀⠜⠿⠿⠳⠀⢀⣀⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⡿⠻⣿⣿⣿⣿⣿⣾⣶⣶⣷⣿⣿⣿⣿⣿⡻⢿⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠠⣶⣾⣿⣿⣿⡿⠟⠉⣤⡾⠋⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⠙⠷⣦⡈⠛⢾⣿⣿⣿⣿⣶⠄⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠀⠀⠉⠉⠀⠾⠿⠿⠃⠘⣿⣿⣿⣿⠇⠈⠿⠿⠷⠀⠉⠉⠀⠀⠉⠉⠉⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡿⠉⣿⣿⡉⢿⣧⡀⠀⠀⠀⠀⡄⢂⣀⠀⠀⠀⠀⣊⠄⠴⠐⣤⡀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⠀⠀⠈⠩⠡⠔⠔⢤⣤⣤⣉⡃⠀⠀⠀⠐⢋⣭⣴⡀⠀⢀⣧⠠⠖⠘⣡⠈⢿⡆⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⢀⣤⠖⣻⣿⡿⠃⠀⢀⡀⠀⠀⠀⠀⠀⠈⠛⠀⢉⣶⣴⣤⣤⡀⡀⣀⠛⠻⣷⣀⣴⣿⣄⠘⣡⠡⠖⢸⡯⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠛⠟⠢⢴⣿⠃⠀⣀⣸⠁⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣯⣩⣉⣉⡂⢘⡈⠃⡆⢩⠙⠻⣷⣄⣁⢂⣡⡾⠃⠀⠀]],
  [[⠀⠀⠀⠀⠀⢠⡐⢠⣿⡗⠘⠇⠀⠐⠛⢛⣢⡀⢀⠀⠀⣤⣴⡈⣿⣿⣿⣿⡟⡛⠟⠿⠆⠻⠛⢦⣌⡘⠅⠦⠉⡋⠛⠉⠀⠀⠀⠀]],
  [[⠀⠀⠀⢠⡘⠂⢰⣿⣿⠇⣡⠀⠀⣿⡿⠿⠿⢽⣶⣦⣀⢛⠙⢿⠛⠚⠻⢿⣿⣿⣿⣷⣶⡀⠀⠈⢿⣿⣃⡀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⢒⠂⢠⣿⣿⣿⠠⠶⠀⠠⣴⣶⣾⣾⣾⣿⣿⣿⣿⣷⣶⠀⠀⠀⠀⠈⠹⢦⣬⣬⡁⠀⠀⠘⠋⠥⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⢈⠥⠀⣼⣿⠟⢡⡘⠁⡬⠁⢋⣉⣍⣍⣭⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⢀⡟⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠠⢒⠰⠋⣅⠚⢂⣴⡀⠖⡰⡙⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⡧⠀⠀⢀⡴⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⢩⠄⢓⣤⣾⣿⣿⣧⠘⡠⢁⠐⢶⣷⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⣰⣾⣶⡦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⣠⡄⠞⡈⢿⣿⣿⣿⣿⣄⠀⠋⡤⠀⠉⠡⣥⣽⣿⣿⣿⣿⣿⣆⣼⣉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠈⢡⠂⠻⣿⣿⣿⣿⣷⣦⣀⠋⡄⢀⠀⠈⠉⠛⠛⠛⠋⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠚⢡⠀⡈⠙⠻⠿⣿⣿⣷⣦⠘⠛⠖⠦⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠈⠘⠂⢆⢰⡀⣄⠨⠉⠉⢻⣿⣿⡿⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
  [[⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]],
}
dashboard.section.buttons.val = {
  dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
  dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
  dashboard.button("p", "  Find project", ":Telescope projects <CR>"),
  dashboard.button("r", "  Recently used files", ":Telescope oldfiles <CR>"),
  dashboard.button("t", "  Find text", ":Telescope live_grep <CR>"),
  dashboard.button("I", " Neorg Home", ":e ~/vimwiki/home/index.norg<CR>"),
  dashboard.button("i", "  init.lua", ":e ~/.config/nvim/init.lua <CR>"),
  dashboard.button("P", "  Plugins", ":e ~/.config/nvim/lua/user/plugins.lua <CR>"),
  dashboard.button("q", "  Quit Neovim", ":qa<CR>"),
}

local function footer()
  -- NOTE: requires the fortune-mod package to work
  -- local handle = io.popen("fortune")
  -- local fortune = handle:read("*a")
  -- handle:close()
  -- return fortune
  return "matt-camp.com"
end

dashboard.section.footer.val = footer()

dashboard.section.footer.opts.hl = "Type"
dashboard.section.header.opts.hl = "Include"
dashboard.section.buttons.opts.hl = "Keyword"

dashboard.opts.opts.noautocmd = true
-- vim.cmd([[autocmd User AlphaReady echo 'ready']])
alpha.setup(dashboard.opts)
```


#### lualine


```lua 
use({
  "nvim-lualine/lualine.nvim",
  requires = { "kyazdani42/nvim-web-devicons", opt = true },
})
```

```lua 
local status_ok, lualine = pcall(require, "lualine")
if not status_ok then
  return
end

local hide_in_width = function()
  return vim.fn.winwidth(0) > 80
end

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  sections = { "error", "warn" },
  symbols = { error = " ", warn = " " },
  colored = false,
  update_in_insert = false,
  always_visible = true,
  globalstatus = true,
}

local diff = {
  "diff",
  colored = false,
  symbols = { added = " ", modified = " ", removed = " " }, -- changes diff symbols
  cond = hide_in_width
}

local mode = {
  "mode",
  fmt = function(str)
    return "-- " .. str .. " --"
  end,
}

local filetype = {
  "filetype",
  icons_enabled = false,
  icon = nil,
}

local branch = {
  "branch",
  icons_enabled = true,
  icon = "",
}

local location = {
  "location",
  padding = 0,
}

-- cool function for progress
local progress = function()
  local current_line = vim.fn.line(".")
  local total_lines = vim.fn.line("$")
  local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
  local line_ratio = current_line / total_lines
  local index = math.ceil(line_ratio * #chars)
  return chars[index]
end

local spaces = function()
  return "spaces: " .. vim.api.nvim_buf_get_option(0, "shiftwidth")
end
lualine.setup({
  options = {
    icons_enabled = true,
    theme = "auto",
    section_separators = { left = '', right = '' },
    component_separators = { left = '', right = '' },
    disabled_filetypes = { "alpha", "dashboard", "NvimTree", "Outline" },
    always_divide_middle = true,
  },
  sections = {
    lualine_a = { branch, diagnostics },
    lualine_b = { mode },
    lualine_c = {},
    -- lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_x = { diff, spaces, "encoding", filetype },
    lualine_y = { location },
    lualine_z = { progress },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = {},
})
```


#### bufferline


```lua 
use({ "akinsho/bufferline.nvim", tag = "v2.*", requires = "kyazdani42/nvim-web-devicons" })
```

```lua 
local status_ok, bufferline = pcall(require, "bufferline")
if not status_ok then
  return
end

bufferline.setup({
  options = {
    numbers = "none", -- | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
    close_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
    right_mouse_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
    left_mouse_command = "buffer %d", -- can be a string | function, see "Mouse actions"
    middle_mouse_command = nil, -- can be a string | function, see "Mouse actions"
    -- NOTE: this plugin is designed with this icon in mind,
    -- and so changing this is NOT recommended, this is intended
    -- as an escape hatch for people who cannot bear it for whatever reason
    indicator = {
      icon = "▎",
      style = "icon"
    },
    buffer_close_icon = "",
    -- buffer_close_icon = '',
    modified_icon = "●",
    close_icon = "",
    -- close_icon = '',
    left_trunc_marker = "",
    right_trunc_marker = "",
    --- name_formatter can be used to change the buffer's label in the bufferline.
    --- Please note some names can/will break the
    --- bufferline so use this at your discretion knowing that it has
    --- some limitations that will *NOT* be fixed.
    -- name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
    --   -- remove extension from markdown files for example
    --   if buf.name:match('%.md') then
    --     return vim.fn.fnamemodify(buf.name, ':t:r')
    --   end
    -- end,
    max_name_length = 30,
    max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
    tab_size = 21,
    diagnostics = false, -- | "nvim_lsp" | "coc",
    diagnostics_update_in_insert = false,
    -- diagnostics_indicator = function(count, level, diagnostics_dict, context)
    --   return "("..count..")"
    -- end,
    -- NOTE: this will be called a lot so don't do any heavy processing here
    -- custom_filter = function(buf_number)
    --   -- filter out filetypes you don't want to see
    --   if vim.bo[buf_number].filetype ~= "<i-dont-want-to-see-this>" then
    --     return true
    --   end
    --   -- filter out by buffer name
    --   if vim.fn.bufname(buf_number) ~= "<buffer-name-I-dont-want>" then
    --     return true
    --   end
    --   -- filter out based on arbitrary rules
    --   -- e.g. filter out vim wiki buffer from tabline in your work repo
    --   if vim.fn.getcwd() == "<work-repo>" and vim.bo[buf_number].filetype ~= "wiki" then
    --     return true
    --   end
    -- end,
    offsets = { { filetype = "NvimTree", text = "", padding = 1 } },
    show_buffer_icons = true,
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
    persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
    -- can also be a table containing 2 custom separators
    -- [focused and unfocused]. eg: { '|', '|' }
    separator_style = "thin", -- | "thick" | "thin" | { 'any', 'any' },
    enforce_regular_tabs = true,
    always_show_bufferline = true,
    -- sort_by = 'id' | 'extension' | 'relative_directory' | 'directory' | 'tabs' | function(buffer_a, buffer_b)
    --   -- add custom logic
    --   return buffer_a.modified > buffer_b.modified
    -- end
  },
  highlights = {
    fill = {
      fg = { attribute = "fg", highlight = "#ff0000" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    background = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },

    -- buffer_selected = {
    --   fg = {attribute='fg',highlight='#ff0000'},
    --   bg = {attribute='bg',highlight='#0000ff'},
    --   underline = 'none'
    --   },
    buffer_visible = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },

    close_button = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    close_button_visible = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    -- close_button_selected = {
    --   fg = {attribute='fg',highlight='TabLineSel'},
    --   bg ={attribute='bg',highlight='TabLineSel'}
    --   },

    tab_selected = {
      fg = { attribute = "fg", highlight = "Normal" },
      bg = { attribute = "bg", highlight = "Normal" },
    },
    tab = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    tab_close = {
      -- fg = {attribute='fg',highlight='LspDiagnosticsDefaultError'},
      fg = { attribute = "fg", highlight = "TabLineSel" },
      bg = { attribute = "bg", highlight = "Normal" },
    },

    --		duplicate_selected = {
    --			fg = { attribute = "fg", highlight = "TabLineSel" },
    --			bg = { attribute = "bg", highlight = "TabLineSel" },
    --			underline = "italic",
    --		},
    --		duplicate_visible = {
    --			fg = { attribute = "fg", highlight = "TabLine" },
    --			bg = { attribute = "bg", highlight = "TabLine" },
    --			underline = "italic",
    --		},
    --		duplicate = {
    --			fg = { attribute = "fg", highlight = "TabLine" },
    --			bg = { attribute = "bg", highlight = "TabLine" },
    --			underline = "italic",
    --		},

    modified = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    modified_selected = {
      fg = { attribute = "fg", highlight = "Normal" },
      bg = { attribute = "bg", highlight = "Normal" },
    },
    modified_visible = {
      fg = { attribute = "fg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },

    separator = {
      fg = { attribute = "bg", highlight = "TabLine" },
      bg = { attribute = "bg", highlight = "TabLine" },
    },
    separator_selected = {
      fg = { attribute = "bg", highlight = "Normal" },
      bg = { attribute = "bg", highlight = "Normal" },
    },
    -- separator_visible = {
    --   fg = {attribute='bg',highlight='TabLine'},
    --   bg = {attribute='bg',highlight='TabLine'}
    --   },
    indicator_selected = {
      fg = { attribute = "fg", highlight = "LspDiagnosticsDefaultHint" },
      bg = { attribute = "bg", highlight = "Normal" },
    },
  },
})
```


#### scrollbars


```lua 
use("petertriho/nvim-scrollbar")
```

```lua 
require("scrollbar").setup({
  show = true,
  show_in_active_only = false,
  set_highlights = true,
  folds = 1000, -- handle folds, set to number to disable folds if no. of lines in buffer exceeds this
  max_lines = false, -- disables if no. of lines in buffer exceeds this
  handle = {
    text = " ",
    color = nil,
    cterm = nil,
    highlight = "CursorColumn",
    hide_if_all_visible = true, -- Hides handle if all lines are visible
  },
  marks = {
    Search = {
      text = { "-", "=" },
      priority = 0,
      color = nil,
      cterm = nil,
      highlight = "Search",
    },
    Error = {
      text = { "-", "=" },
      priority = 1,
      color = nil,
      cterm = nil,
      highlight = "DiagnosticVirtualTextError",
    },
    Warn = {
      text = { "-", "=" },
      priority = 2,
      color = nil,
      cterm = nil,
      highlight = "DiagnosticVirtualTextWarn",
    },
    Info = {
      text = { "-", "=" },
      priority = 3,
      color = nil,
      cterm = nil,
      highlight = "DiagnosticVirtualTextInfo",
    },
    Hint = {
      text = { "-", "=" },
      priority = 4,
      color = nil,
      cterm = nil,
      highlight = "DiagnosticVirtualTextHint",
    },
    Misc = {
      text = { "-", "=" },
      priority = 5,
      color = nil,
      cterm = nil,
      highlight = "Normal",
    },
    GitAdd = {
      text = "┆",
      priority = 5,
      color = nil,
      cterm = nil,
      highlight = "GitSignsAdd",
    },
    GitChange = {
      text = "┆",
      priority = 5,
      color = nil,
      cterm = nil,
      highlight = "GitSignsChange",
    },
    GitDelete = {
      text = "▁",
      priority = 5,
      color = nil,
      cterm = nil,
      highlight = "GitSignsDelete",
    },
  },
  excluded_buftypes = {
    "terminal",
  },
  excluded_filetypes = {
    "prompt",
    "TelescopePrompt",
    "noice",
  },
  autocmd = {
    render = {
      "BufWinEnter",
      "TabEnter",
      "TermEnter",
      "WinEnter",
      "CmdwinLeave",
      "TextChanged",
      "VimResized",
      "WinScrolled",
    },
    clear = {
      "BufWinLeave",
      "TabLeave",
      "TermLeave",
      "WinLeave",
    },
  },
  handlers = {
    diagnostic = true,
    search = false, -- Requires hlslens to be loaded
    gitsigns = false, -- Requires gitsigns.nvim
  },
})
```


#### colorizer


```lua 
use("norcalli/nvim-colorizer.lua")
```

```lua 
require 'colorizer'.setup()
```





#### Current Theme (ayu)


This is my current theme and its configuration. I can't take credit I found the config elsewhere.. think it was posted/linked to on Reddit. I did make a couple tweaks to fix a few color issues. Don't think most of the config is really used but some is... 

```lua 
use("Shatur/neovim-ayu")
```

```lua 
require('ayu').setup({
  mirage = false, -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
  overrides = {}, -- A dictionary of group names, each associated with a dictionary of parameters (`bg`, `fg`, `sp` and `style`) and colors in hex.
})

vim.cmd([[
try
 colorscheme ayu
catch /^Vim\%((\a\+)\)\=:E185/
 colorscheme auto
 set background=dark
endtry
]])

-- Ayu
local colors = {}
colors.accent = "#E6B450"
colors.bg = "#0A0E14"
colors.fg = "#B3B1AD"
colors.ui = "#4D5566"

colors.tag = "#39BAE6"
colors.func = "#FFB454"
colors.entity = "#59C2FF"
colors.string = "#C2D94C"
colors.regexp = "#95E6CB"
colors.markup = "#F07178"
colors.keyword = "#FF8F40"
colors.special = "#E6B673"
colors.comment = "#626A73"
colors.constant = "#FFEE99"
colors.operator = "#F29668"
colors.error = "#FF3333"

colors.line = "#00010A"
colors.panel_bg = "#0D1016"
colors.panel_shadow = "#00010A"
colors.panel_border = "#000000"
colors.gutter_normal = "#323945"
colors.gutter_active = "#464D5E"
colors.selection_bg = "#273747"
colors.selection_inactive = "#1B2733"
colors.selection_border = "#304357"
colors.guide_active = "#393F4D"
colors.guide_normal = "#242A35"

colors.vcs_added = "#91B362"
colors.vcs_modified = "#6994BF"
colors.vcs_removed = "#D96C75"

colors.vcs_added_bg = "#1D2214"
colors.vcs_removed_bg = "#2D2220"

colors.fg_idle = "#3E4B59"
colors.warning = "#FF8F40"

colors.dark0_hard = "#0A0E14"
colors.dark0 = "#282828"
colors.dark0_soft = "#32302f"
colors.dark1 = "#00010A"
colors.dark2 = "#504945"
colors.dark3 = "#665c54"
colors.dark4 = "#7c6f64"
colors.light0_hard = "#f9f5d7"
colors.light0 = "#fbf1c7"
colors.light0_soft = "#f2e5bc"
colors.light1 = "#ebdbb2"
colors.light2 = "#d5c4a1"
colors.light3 = "#bdae93"
colors.light4 = "#a89984"
colors.bright_red = "#fb4934"
colors.bright_green = "#b8bb26"
colors.bright_yellow = "#fabd2f"
colors.bright_blue = "#83a598"
colors.bright_purple = "#d3869b"
colors.bright_aqua = "#8ec07c"
colors.bright_orange = "#fe8019"
colors.neutral_red = "#cc241d"
colors.neutral_green = "#98971a"
colors.neutral_yellow = "#d79921"
colors.neutral_blue = "#458588"
colors.neutral_purple = "#b16286"
colors.neutral_aqua = "#689d6a"
colors.neutral_orange = "#d65d0e"
colors.faded_red = "#9d0006"
colors.faded_green = "#79740e"
colors.faded_yellow = "#b57614"
colors.faded_blue = "#076678"
colors.faded_purple = "#8f3f71"
colors.faded_aqua = "#427b58"
colors.faded_orange = "#af3a03"
colors.gray = "#928374"

local function set_colors(fg, bg)
  return "guifg=" .. fg .. " guibg=" .. bg
end
-- 
-- -- Applying colors
local api = vim.api
api.nvim_command("hi StatusDefault " .. set_colors(colors.fg, colors.bg))
api.nvim_command("hi StatusVimNormal " .. set_colors(colors.bg, colors.accent))
api.nvim_command("hi StatusVimInsert " .. set_colors(colors.bg, colors.neutral_blue))
api.nvim_command("hi StatusVimVisual " .. set_colors(colors.bg, colors.func))
api.nvim_command("hi StatusVimReplace " .. set_colors(colors.bg, colors.entity))
api.nvim_command("hi StatusVimEnter " .. set_colors(colors.bg, colors.string))
api.nvim_command("hi StatusVimMore " .. set_colors(colors.bg, colors.regexp))
api.nvim_command("hi StatusVimSelect " .. set_colors(colors.bg, colors.markup))
api.nvim_command("hi StatusVimCmd " .. set_colors(colors.bg, colors.keyword))
api.nvim_command("hi StatusVimShell " .. set_colors(colors.bg, colors.special))
api.nvim_command("hi StatusVimTerm " .. set_colors(colors.bg, colors.comment))
api.nvim_command("hi StatusModified " .. set_colors(colors.bg, colors.constant))
api.nvim_command("hi StatusLineNumber " .. set_colors(colors.bg, colors.operator))
api.nvim_command("hi StatusColumnNumber " .. set_colors(colors.bg, colors.error))
api.nvim_command("hi StatusFileInfo " .. set_colors(colors.keyword, colors.bg))
api.nvim_command("hi StatusGitInfo " .. set_colors(colors.bright_green, colors.bg))
api.nvim_command("hi StatusLSPProgress " .. set_colors(colors.neutral_blue, colors.bg))
api.nvim_command("hi StatusLSPError " .. set_colors(colors.error, colors.bg))
api.nvim_command("hi StatusLSPWarn " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi StatusLSPInfo " .. set_colors(colors.entity, colors.bg))
api.nvim_command("hi StatusLSPHin " .. set_colors(colors.tag, colors.bg))
api.nvim_command("hi StatusLSPStatus " .. set_colors(colors.tag, colors.bg))
api.nvim_command("hi StatusCwd " .. set_colors(colors.keyword, colors.bg))
api.nvim_command("hi StatusCursor " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi WhichKeyFloat " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi SessionName " .. set_colors(colors.string, colors.bg))
api.nvim_command("hi WildMenu guifg=#0A0E14 guibg=#f07178")
api.nvim_command("hi WildMenu guifg=#0A0E14 guibg=#f07178")
api.nvim_command("hi @neorg.tags.ranged_verbatim.code_block guibg=#171717")

```



```lua 
if PACKER_BOOTSTRAP then
  require("packer").sync()
end
end)
```


## Snippets



## General Key Maps



#### Normal Mode


```lua 
which_key.register({
  -- Better window navigation
  ["<C-h>"] = { "<C-w>h", "Move One Window Left" },
  ["<C-j>"] = { "<C-w>j", "Move One Window Down" },
  ["<C-k>"] = { "<C-w>k", "Move One Window Up" },
  ["<C-l>"] = { "<C-w>l", "Move One Window Right" },
  -- Buffer navigation
  ["<S-l>"] = { ":bnext<CR>", "Next Buffer" },
  ["<S-h>"] = { ":bprevious<CR>", "Previous Buffer" },
  ["<C-s>"] = { ":w<CR>", "Save" },
  ["<C-q>"] = { ":q<CR>", "Quit" },
  Y = { "y$", "Yank from cursor to end of line" },
  ["<C-Up>"] = { ":resize -2<CR>", "Decrease Current Window Size Horizontally" },
  ["<C-Down>"] = { ":resize +2<CR>", "Increase Current Window Size Vertically" },
  ["<C-Left>"] = { ":vertical -2<CR>", "Decrease Current Window Size Horizontally" },
  ["<C-Right>"] = { ":vertical +2<CR>", "Increase Current Window Size Vertically" },
  -- Scroll 5 rows at a time
  ["<S-D>"] = { "5<C-e>", "Scroll down 5 rows at a time" },
  ["<S-E>"] = { "5<C-y>", "Scroll up 5 rows at a time" },
  ["<F8>"] = { ":set list!<CR>", "Toggle Unprintable Charactes" },
})
```


#### Visual Mode


```lua 
which_key.register({
  p = { '"_dP', "Paste without overwriting the register" },
}, { mode = "v" })
```


#### Insert Mode


```lua 
which_key.register({
  ["<C-s>"] = { "<esc>:w<cr>", "Save" },
  ["<C-q>"] = { "<esc>:Bclose<cr>", "Quit" },
  ["<F8>"] = { "<C-o>:set list!<CR>", "Toggle Unprintable Charactes" },
}, { mode = "i" })

```

