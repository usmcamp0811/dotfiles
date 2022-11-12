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
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  vim.notify("shit broke")
  return
end

-- TODO: is there away to do two requires with pcall
-- local status_still_ok, which_key = pcall(require, "which-key")
-- if not status_still_ok then
-- 	return
-- end

-- which_key.register({
--   p = {
--     name = "Packer",
--     c = { "<cmd>PackerCompile<cr>", "Compile" },
--     i = { "<cmd>PackerInstall<cr>", "Install" },
--     s = { "<cmd>PackerSync<cr>", "Sync" },
--     S = { "<cmd>PackerStatus<cr>", "Status" },
--     u = { "<cmd>PackerUpdate<cr>", "Update" },
--   },
-- },
--   { prefix = "<leader>" }
-- )

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

-- Install your plugins here
return packer.startup(function(use)
  -- Basic stuff needed
  use("wbthomason/packer.nvim") -- Have packer manage itself
  use("nvim-lua/popup.nvim") -- An implementation of the Popup API from vim in Neovim
  use("nvim-lua/plenary.nvim") -- Useful lua functions used ny lots of plugins
  use("lewis6991/impatient.nvim") -- suppose to speed up lua load times

  -- use 'vim-pandoc/vim-pandoc' -- this is not needed treesitter or something has got the filetypes
  use("vim-pandoc/vim-pandoc-syntax")
  use({
    "chentoast/marks.nvim",
    config = function()
      require("user.plug-setting.marks")
    end,
  })

  -- use "kshenoy/vim-signature"
  use("ahmedkhalf/project.nvim")
  use("kyazdani42/nvim-tree.lua")
  use("vimwiki/vimwiki")

  -- use "renerocksai/telekasten.nvim" -- not quite ready to replace vimwiki
  use("mzlogin/vim-markdown-toc")
  use("itchyny/calendar.vim")
  use {'edluffy/hologram.nvim'}
  use("gioele/vim-autoswap")

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
  -- Notebook like functions / REPL
  -- use("JuliaEditorSupport/julia-vim")
  -- use({ "ExpandingMan/julia-vim", branch = "emfix1" })
  -- use("kdheepak/JuliaFormatter.vim")
  use({"https://gitlab.com/usmcamp0811/nvim-julia-autotest",
    config = function()
      require("julia-autotest").setup()
    end
  })
  use("jpalardy/vim-slime") -- allow vim to send julia / python commands to the repl
  use({ "hanschen/vim-ipython-cell", ft = { "python", "julia", "markdown.pandoc" } })
  -- use({ "mroavi/vim-julia-cell", ft = { "julia", "jl" } })
  use("metakirby5/codi.vim")
  -- use({ "/home/mcamp/code/conjure", branch = "develop" })
  use({ "https://github.com/usmcamp0811/conjure.git", branch = "develop" })
  -- use({ "Olical/conjure" })
  -- use({ "Grazfather/conjure", branch = "which-key-descs" })
  use("Olical/aniseed")
  use("radenling/vim-dispatch-neovim")
  use("clojure-vim/vim-jack-in")
  use("tpope/vim-dispatch")
  use("guns/vim-sexp")
  use("tpope/vim-sexp-mappings-for-regular-people")

  use("godlygeek/tabular")
  use("lervag/vimtex") -- for writing latex
  use("lambdalisue/suda.vim") -- runs `sudo` when needed

  -- random plugins
  use("unblevable/quick-scope") -- easier horizontal jumping
  use("ggandor/leap.nvim") --  better vertical jumping
  use("https://github.com/JoosepAlviste/nvim-ts-context-commentstring.git")
  use("akinsho/toggleterm.nvim")
  use("folke/which-key.nvim")
  use("moll/vim-bbye")
  use({
    "numToStr/Comment.nvim",
    tag = "v0.6.1",
    --branch = "master",
  })
  use("windwp/nvim-autopairs")
  use("907th/vim-auto-save")
  use("jbyuki/nabla.nvim") -- neat looking math pluging
  use({
    "weirongxu/plantuml-previewer.vim",
    requires = { { "tyru/open-browser.vim", opt = false }, { "aklt/plantuml-syntax", opt = false } },
  })
  use("aklt/plantuml-syntax")
  use("bluz71/vim-nightfly-guicolors")
  use("bluz71/vim-moonfly-colors")
  use("folke/lsp-colors.nvim")
  use("humanoid-colors/vim-humanoid-colorscheme")
  use("lalitmee/cobalt2.nvim")
  use("konosubakonoakua/synthwave84.nvim")
  use({
    "catppuccin/nvim",
    as = "catppuccin",
    run = ":CatppuccinCompile",
  })
  use { 'sindrets/diffview.nvim', requires = 'nvim-lua/plenary.nvim' }
  use "samjwill/nvim-unception"
  use "ii14/neorepl.nvim"
  use {
    "narutoxy/silicon.lua",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
      require('silicon').setup({})
    end
  }

  use({
    "nvim-neorg/neorg",
    -- tag = "0.0.12",
    run = ":Neorg sync-parsers",
    -- ft = "norg",
    branch = "main",
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

  -- UI
  use({
    "nvim-lualine/lualine.nvim",
    requires = { "kyazdani42/nvim-web-devicons", opt = true },
  })
  use("lukas-reineke/indent-blankline.nvim")
  use("norcalli/nvim-colorizer.lua")
  use("dhruvasagar/vim-table-mode")
  use("lunarvim/darkplus.nvim")
  use("joshdick/onedark.vim")
  use("rebelot/kanagawa.nvim")
  use("EdenEast/nightfox.nvim")
  use("Yazeed1s/minimal.nvim")
  use("chrisbra/csv.vim")
  use("goolord/alpha-nvim")
  use({
    "AckslD/nvim-FeMaco.lua",
    config = require('femaco').setup({
  -- should prepare a new buffer and return the winid
  -- by default opens a floating window
  -- provide a different callback to change this behaviour
  -- @param opts: the return value from float_opts
  prepare_buffer = function(opts)
    local buf = vim.api.nvim_create_buf(false, false)
    return vim.api.nvim_open_win(buf, true, opts)
  end,
  -- should return options passed to nvim_open_win
  -- @param code_block: data about the code-block with the keys
  --   * range
  --   * lines
  --   * lang
  -- float_opts = function(code_block)
  --   return {
  --     relative = 'cursor',
  --     width = clip_val(5, 120, vim.api.nvim_win_get_width(0) - 10), 
  --     height = clip_val(5, #code_block.lines, vim.api.nvim_win_get_height(0) - 6),
  --     anchor = 'NW',
  --     row = 0,
  --     col = 0,
  --     style = 'minimal',
  --     border = 'rounded',
  --     zindex = 1,
  --   }
  -- end,
  -- return filetype to use for a given lang
  -- lang can be nil
  ft_from_lang = function(lang)
    return lang
  end,
  -- what to do after opening the float
  post_open_float = function(winnr)
    vim.wo.signcolumn = 'no'
  end,
  -- create the path to a temporary file
  create_tmp_filepath = function(filetype)
    return os.tmpname()
  end,
  -- if a newline should always be used, useful for multiline injections
  -- which separators needs to be on separate lines such as markdown, neorg etc
  -- @param base_filetype: The filetype which FeMaco is called from, not the
  -- filetype of the injected language (this is the current buffer so you can
  -- get it from vim.bo.filetyp).
  ensure_newline = function(base_filetype)
    return false
  end,
})
  })
  use("davidgranstrom/nvim-markdown-preview")
  use({
    "anuvyklack/pretty-fold.nvim",
    config = function()
      require("user.plug-setting.pretty-fold")
    end,
    ft_setup = { "neorg", {} },
  })
  -- use "jceb/vim-orgmode"
  use({
    "anuvyklack/fold-preview.nvim",
    requires = "anuvyklack/keymap-amend.nvim",
    config = function()
      require("fold-preview").setup()
    end,
  })
  use("shoumodip/nvim-literate")
  -- use "frabjous/knap"
  -- use "savq/paq-nvim"
  -- use { 'michaelb/sniprun', run = 'bash ./install.sh'}
  use("rcarriga/nvim-notify")
  use({
      "kylechui/nvim-surround",
      tag = "*", -- Use for stability; omit to use `main` branch for the latest features
      config = function()
          require("nvim-surround").setup({
              -- Configuration here, or leave empty to use defaults
          })
      end
  })

  use({ "akinsho/bufferline.nvim", tag = "v2.*", requires = "kyazdani42/nvim-web-devicons" })
  use({ "kevinhwang91/rnvimr", run = "make sync" }) -- ranger in vima

  -- cmp plugins
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
  use({
    "hrsh7th/nvim-cmp",
    requires = {
      { "kdheepak/cmp-latex-symbols" },
    },
  })
  use({
    "samodostal/image.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
    },
  })
  use("phaazon/mind.nvim")
  use("saadparwaiz1/cmp_luasnip") -- snippet completions
  -- snippets
  use("L3MON4D3/LuaSnip") --snippet engine
  use("rafamadriz/friendly-snippets") -- a bunch of snippets to use
  use("honza/vim-snippets")

  -- LSP
  use("neovim/nvim-lspconfig") -- enable LSP
  use("williamboman/nvim-lsp-installer") -- simple to use language server installer

  use("williamboman/mason.nvim")
  use("williamboman/mason-lspconfig.nvim")
  use("b0o/SchemaStore.nvim")
  use("tamago324/nlsp-settings.nvim")
  -- use "lukas-reineke/lsp-format.nvim"
  use("jose-elias-alvarez/null-ls.nvim") -- for formatters and linters
  use("https://git.sr.ht/~whynothugo/lsp_lines.nvim")

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

  -- Lua
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

  use {
    'gorbit99/codewindow.nvim',
    config = function()
      local codewindow = require('codewindow')
      codewindow.setup()
      codewindow.apply_default_keybinds()
    end,
  }

  -- Telescope
  use("nvim-telescope/telescope.nvim")
  use("nvim-telescope/telescope-symbols.nvim")
  use("nvim-telescope/telescope-media-files.nvim")

  use 'David-Kunz/markid' -- better function syntax higlighting
  -- Treesitter
  use({
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
    markid = { enable = true }
  })
  use({
    "nvim-treesitter/nvim-treesitter-textobjects",
    run = ":TSUpdate",
  })
  use({
    "RRethy/nvim-treesitter-textsubjects",
  })
  use("windwp/nvim-ts-autotag")
  use("nvim-treesitter/playground")
  use("echasnovski/mini.nvim")
  use {'kevinhwang91/nvim-hlslens'}
  -- Git
  use("petertriho/nvim-scrollbar")
  use({
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
			require("scrollbar.handlers.gitsigns").setup()
    end,
  })
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
