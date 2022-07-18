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

  use "ahmedkhalf/project.nvim"
  use "kyazdani42/nvim-tree.lua"

  -- Notebook like functions / REPL
  use "JuliaEditorSupport/julia-vim"
  use "jpalardy/vim-slime" -- allow vim to send julia / python commands to the repl
  use({"hanschen/vim-ipython-cell", ft = { "python", "julia", "markdown.pandoc" }})
  use({"mroavi/vim-julia-cell", ft = { "julia", "jl" }})
  use "metakirby5/codi.vim"

  -- random plugins
  use "unblevable/quick-scope" -- easier horizontal jumping
  use "justinmk/vim-sneak" --  better vertical jumping
  use "JoosepAlviste/nvim-ts-context-commentstring"
  use "akinsho/toggleterm.nvim"
  use "folke/which-key.nvim"
  use "moll/vim-bbye"
  use "numToStr/Comment.nvim"
  use "windwp/nvim-autopairs"
  use "907th/vim-auto-save"

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
  use "Yazeed1s/minimal.nvim"
  use "goolord/alpha-nvim"

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

  -- Telescope
  use "nvim-telescope/telescope.nvim"

  -- Treesitter
  use({
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
  })

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
