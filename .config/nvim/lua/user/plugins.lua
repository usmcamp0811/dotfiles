local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  vim.notify("shit broke")
  return
end

-- TODO: is there away to do two requires with pcall
local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  p = {
    name = "Packer",
    c = { "<cmd>PackerCompile<cr>", "Compile" },
    i = { "<cmd>PackerInstall<cr>", "Install" },
    s = { "<cmd>PackerSync<cr>", "Sync" },
    S = { "<cmd>PackerStatus<cr>", "Status" },
    u = { "<cmd>PackerUpdate<cr>", "Update" },
  },
},
  { prefix = "<leader>" }
)

-- Have packer use a popup window
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

-- Install your plugins here
return packer.startup(function(use)

  -- Basic stuff needed
  use "wbthomason/packer.nvim" -- Have packer manage itself
  use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
  use "nvim-lua/plenary.nvim" -- Useful lua functions used ny lots of plugins
  use "lewis6991/impatient.nvim" -- suppose to speed up lua load times

  -- use 'vim-pandoc/vim-pandoc' -- this is not needed treesitter or something has got the filetypes
  use 'vim-pandoc/vim-pandoc-syntax'

  use "ahmedkhalf/project.nvim"
  use "kyazdani42/nvim-tree.lua"
  use "vimwiki/vimwiki"

  -- use "renerocksai/telekasten.nvim" -- not quite ready to replace vimwiki
  use "mzlogin/vim-markdown-toc"
  use "itchyny/calendar.vim"
  -- use {'edluffy/hologram.nvim'}
  use "gioele/vim-autoswap"

  -- Notebook like functions / REPL
  use "JuliaEditorSupport/julia-vim"
  use "kdheepak/JuliaFormatter.vim"
  use "jpalardy/vim-slime" -- allow vim to send julia / python commands to the repl
  use({"hanschen/vim-ipython-cell", ft = { "python", "julia", "markdown.pandoc" }})
  use({"mroavi/vim-julia-cell", ft = { "julia", "jl" }})
  use "metakirby5/codi.vim"

  use "godlygeek/tabular"
  use "lervag/vimtex" -- for writing latex
  use "lambdalisue/suda.vim" -- runs `sudo` when needed

  -- random plugins
  use "unblevable/quick-scope" -- easier horizontal jumping
  use "ggandor/lightspeed.nvim" --  better vertical jumping
  use "JoosepAlviste/nvim-ts-context-commentstring"
  use "akinsho/toggleterm.nvim"
  use "folke/which-key.nvim"
  use "moll/vim-bbye"
  use "numToStr/Comment.nvim"
  use "windwp/nvim-autopairs"
  use "907th/vim-auto-save"
  use "jbyuki/nabla.nvim" -- neat looking math pluging
  use( {
    "weirongxu/plantuml-previewer.vim",
    requires = { { "tyru/open-browser.vim", opt = false }, { "aklt/plantuml-syntax", opt = false } }
  } )
  use "aklt/plantuml-syntax"
  use "bluz71/vim-nightfly-guicolors"
  use "bluz71/vim-moonfly-colors"
  use "folke/lsp-colors.nvim"
  use "humanoid-colors/vim-humanoid-colorscheme"
  use "lalitmee/cobalt2.nvim"

  use {
    "catppuccin/nvim",
    as = "catppuccin",
    run = ":CatppuccinCompile"
  }

  use {
    "nvim-neorg/neorg",
    config = function()
        require('user.plug-setting.neorg')
    end,
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-neorg/neorg-telescope",
      "esquires/neorg-gtd-project-tags",
      "danymat/neorg-gtd-things",
      "max397574/neorg-contexts",
      "max397574/neorg-kanban"
    },
    tag = "*"
  }

  -- UI
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true }
  }
  use "lukas-reineke/indent-blankline.nvim"
  use "norcalli/nvim-colorizer.lua"
  use "dhruvasagar/vim-table-mode"
  use "lunarvim/darkplus.nvim"
  use "joshdick/onedark.vim"
  use "rebelot/kanagawa.nvim"
  use "EdenEast/nightfox.nvim"
  use "Yazeed1s/minimal.nvim"
  use "goolord/alpha-nvim"
  use "davidgranstrom/nvim-markdown-preview"
  use{ 'anuvyklack/pretty-fold.nvim',
     config = function()
        require('user.plug-setting.pretty-fold')
     end
  }

  use "shoumodip/nvim-literate"
  -- use "frabjous/knap"
  -- use "savq/paq-nvim"
  use { 'michaelb/sniprun', run = 'bash ./install.sh'}
  use "rcarriga/nvim-notify"
  use 'Olical/conjure'
  use {
    "tpope/vim-surround",
    requires = { "tpope/vim-repeat", opt = true }
  }

  use "akinsho/bufferline.nvim"
  use({"kevinhwang91/rnvimr", run = "make sync" }) -- ranger in vima

  -- cmp plugins
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/cmp-cmdline'
  use 'hrsh7th/nvim-cmp'

  -- snippets
  use "L3MON4D3/LuaSnip" --snippet engine
  use "rafamadriz/friendly-snippets" -- a bunch of snippets to use

  -- LSP
  use "neovim/nvim-lspconfig" -- enable LSP
  use "williamboman/nvim-lsp-installer" -- simple to use language server installer
  use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters
  use "https://git.sr.ht/~whynothugo/lsp_lines.nvim"

  -- Telescope
  use "nvim-telescope/telescope.nvim"
  use "nvim-telescope/telescope-symbols.nvim"
  use "nvim-telescope/telescope-media-files.nvim"

  -- Treesitter
  use({
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
  })

  use "nvim-treesitter/playground"
  -- Git
  use {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end
  }
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
