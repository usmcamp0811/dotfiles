# {pkgs,lib, fetchurl, buildPythonPackage, ...}:
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

  '';

  extraPackages = [
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
    pkgs.campground.julia

    # python-env
    # (
    #     pkgs.python3Packages.buildPythonPackage rec {
    #       pname = "kaleido";
    #       version = "0.2.1";
    #       src = pkgs.fetchPypi {
    #         inherit pname version;
    #         sha256 = "sha256:aa21cf1bf1c78f8fa50a9f7d45e1003c387bd3d6fe0a767cfbbf344b95bdc3a8";
    #       };
    #       doCheck = false;
    #       propagatedBuildInputs = [
    #         # Specify dependencies
    #         pkgs.python3Packages.plotly
    #       ];
    #     }
    #   )
    #   (pkgs.python3.withPackages (ps: [
    #     (ps.buildPythonPackage rec {
    #       pname = "kaleido";
    #       version = "0.2.1.post1";
    #       src = pkgs.fetchFromGitHub {
    #         owner = "plotly";
    #         repo = pname;
    #         rev = "v${version}";
    #         sha256 = "0y14dc6z1r8nrcdgzgiml440ca7xlix7b96y50yq6zhya5gnvnqg"; # Replace with the correct hash
    #       };
    #
    #       nativeBuildInputs = [ pkgs.makeWrapper ];
    #       propagatedBuildInputs = [ pkgs.python3Packages.setuptools ];
    # doCheck = false;
    #       # Disable standard build phases for Python that expect a setup.py
    #       dontUseSetuptoolsBuild = true;
    #       dontUseSetuptoolsInstall = true;
    #
    #       # Add additional build steps if necessary
    #       # buildPhase = ''
    #       #   ...
    #       # '';
    #     })
    #   ]))
  ];
}
