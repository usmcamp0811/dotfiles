{ pkgs, ... }: {

  # Import all your configuration modules here
  imports = [
    ./theme.nix
    ./keymaps.nix
    ./options.nix
    ./autocommands.nix
    ./plugins.nix
  ];

  globals.mapleader = " "; # Set the leader key to the spacebar
  extraConfigLua = ''
    require('hlslens').setup()
    vim.cmd [[set clipboard+=unnamedplus]]
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
    vim.opt.expandtab = true
    vim.opt.undodir = vim.fn.expand("$HOME") .. "/.config/nvim/undo"
    vim.opt.undofile = true
    o = vim.opt
    wo = vim.wo
    bo = vim.bo

    o.listchars:append({ eol = "¬" })
    o.listchars:append({ tab = ">·" })
    o.listchars:append({ trail = "~" })
    o.listchars:append({ precedes = "<" })
    o.listchars:append({ space = "␣" })
    o.listchars:append({ extends = ">" })
    o.iskeyword:append("-")
    o.shortmess:append("c")

    wo.number = true
    wo.relativenumber = true

    bo.expandtab = true
    bo.shiftwidth = 2
    bo.softtabstop = 2
    bo.tabstop = 2
    vim.cmd("set expandtab ts=2 sw=2 ai")
    vim.opt.guifont = { "Source Code Pro", ":h8" }

    vim.api.nvim_set_keymap('v', '$', 'g_', { noremap = true, silent = true })

  '';

  extraPackages = [
    pkgs.fd
    pkgs.graphviz
    pkgs.jdk19
    pkgs.jdk
    pkgs.plantuml-c4
    pkgs.xsel
    pkgs.python311Packages.plotly
    pkgs.python311Packages.jupyter_server
    pkgs.libstdcxx5
    pkgs.zlib
    pkgs.gcc
    pkgs.glib
    pkgs.jupyter
    pkgs.qt5.qtbase
    pkgs.qt5.qtwebengine
    pkgs.python311Packages.ipython
    pkgs.python311Packages.jupyter_console
    pkgs.python311Packages.matplotlib-inline
    pkgs.python311Packages.jupyter
    pkgs.python311Packages.jupyter-core
    pkgs.python311Packages.jupyter_server
    pkgs.python311Packages.jupyterlab
    pkgs.python311Packages.ipykernel
    pkgs.python311Packages.qtconsole
    pkgs.python311Packages.xcffib
    pkgs.pandoc
    pkgs.glib
    pkgs.imagemagick
    pkgs.lua54Packages.luarocks
    pkgs.luajitPackages.luarocks
    pkgs.gtk4

  ];
}
