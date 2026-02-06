{ pkgs, config, lib, ... }:
with lib;
with lib.fmf;
let inherit (lib.fmf) override-meta;
in pkgs.mkShell {
  name = "cuda-env-shell";
  buildInputs = with pkgs; [
    gnupg
    autoconf
    curl
    procps
    gnumake
    util-linux
    m4
    gperf
    unzip
    linuxPackages.nvidia_x11
    libGLU
    libGL
    xorg.libXi
    xorg.libXmu
    freeglut
    xorg.libXext
    xorg.libX11
    xorg.libXv
    xorg.libXrandr
    zlib
    ncurses5
    stdenv.cc
    binutils
    stdenv.cc.cc.lib
    cudatoolkit
    poetry
    dioxus-cli
  ];
  propagatedBuildInputs = with pkgs; [ python3Packages.pip ];
  shellHook = ''
    export CUDA_PATH=${pkgs.cudatoolkit}
    export LD_LIBRARY_PATH=${
      pkgs.lib.makeLibraryPath [
        pkgs.glib
        pkgs.linuxPackages.nvidia_x11
        pkgs.libz
        pkgs.libGL
        pkgs.stdenv.cc.cc
      ]
    }
    #export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.cudatoolkit.lib}/lib:${pkgs.cudatoolkit}/lib
    #export RUNPATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.cudatoolkit}/lib/stubs:${pkgs.cudatoolkit_11}/lib:${pkgs.cudatoolkit_11.lib}/lib:$LD_LIBRARY_PATH
    #export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib:${pkgs.stdenv.cc.cc.lib}/lib
    export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
    export EXTRA_CCFLAGS="-I/usr/include"
  '';
}
