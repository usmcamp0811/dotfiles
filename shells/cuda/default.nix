{ pkgs, config, lib, ... }:
with lib;
with lib.campground;
let
  inherit (lib.campground) override-meta;
  cudaFHS = pkgs.buildFHSEnv {
    name = "cuda-env";
    targetPkgs = pkgs:
      with pkgs; [
        git
        gitRepo
        gnupg
        autoconf
        curl
        procps
        gnumake
        util-linux
        m4
        gperf
        unzip
        cudatoolkit
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
      ];
    multiPkgs = pkgs: with pkgs; [ zlib ];
    runScript = "bash";
    profile = ''
      export CUDA_PATH=${pkgs.cudatoolkit}
      # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib
      export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
      export EXTRA_CCFLAGS="-I/usr/include"
    '';
  };
in cudaFHS.env
# pkgs.devshell.mkShell {
#   imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
#   commands = [
#     # {
#     #   name = "python-env";
#     #   command = cudaFHS;
#     # }
#   ];
#   env = [
#     {
#       name = "LD_LIBRARY_PATH";
#       value = "${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib";
#     }
#     {
#       name = "EXTRA_LDFLAGS";
#       value = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
#     }
#     {
#       name = "EXTRA_CCFLAGS";
#       value = "-I/usr/include";
#     }
#     {
#       name = "CUDA_PATH";
#       value = "${pkgs.cudatoolkit}";
#     }
#   ];
# }

