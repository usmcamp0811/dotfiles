{ mkShell, pkgs, inputs, config, lib, system, ... }:
with lib;
with lib.fmf;
let
  inherit (lib.fmf) override-meta;

  # This is required if you get odd errors
  # read the https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md
  pypkgs-build-requirements = {
    pyjulia = [ "setuptools" ];
    julia = [ "setuptools" ];
    juliapkg = [ "setuptools" ];
    urllib3 = [ "hatchling" ];
    juliacall = [ "setuptools" ];
    pandas = [ "versioneer" ];
    sphinxcontrib-jquery = [ "sphinx" "setuptools" ];
    gunicorn = [ "setuptools-scm" ];
    # contourpy = [ "mesonpy" ];
    # numpy = [ "setuptools" ];
  };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg:
          if builtins.isString pkg then builtins.getAttr pkg super else pkg)
          build-requirements);
      })) pypkgs-build-requirements);
  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true;
  };
in pkgs.nix-unstable.mkShell {
  buildInputs = [
    python-env
    pkgs.nix-unstable.gcc
    pkgs.nix-unstable.libunistring
    pkgs.nix-unstable.libidn2
    pkgs.nix-unstable.tzdata
    pkgs.nix-unstable.zlib
    pkgs.nix-unstable.zlib.dev
    pkgs.nix-unstable.readline
    pkgs.nix-unstable.readline.dev
    pkgs.nix-unstable.bzip2
    pkgs.nix-unstable.bzip2.dev
    pkgs.nix-unstable.ncurses
    pkgs.nix-unstable.ncurses.dev
    pkgs.nix-unstable.sqlite
    pkgs.nix-unstable.sqlite.dev
    pkgs.nix-unstable.openssl
    pkgs.nix-unstable.openssl.dev
    pkgs.nix-unstable.libuuid
    pkgs.nix-unstable.libuuid.dev
    pkgs.nix-unstable.gdbm
    pkgs.nix-unstable.lzlib
    pkgs.nix-unstable.tk
    pkgs.nix-unstable.tk.dev
    pkgs.nix-unstable.libffi
    pkgs.nix-unstable.libffi.dev
    pkgs.nix-unstable.expat
    pkgs.nix-unstable.expat.dev
    pkgs.nix-unstable.mailcap
    pkgs.nix-unstable.xz
    pkgs.nix-unstable.xz.dev
    pkgs.nix-unstable.openssl
    pkgs.nix-unstable.unzip
    pkgs.nix-unstable.gnutar
    pkgs.nix-unstable.wget
    pkgs.nix-unstable.curl
    pkgs.nix-unstable.gnugrep
    pkgs.nix-unstable.gawk
    pkgs.nix-unstable.gnused
    pkgs.nix-unstable.pyenv
    pkgs.nix-unstable.bashInteractive
    pkgs.nix-unstable.gnumake
    pkgs.nix-unstable.zlib
    pkgs.nix-unstable.libffi
    pkgs.nix-unstable.readline
    pkgs.nix-unstable.bzip2
    pkgs.nix-unstable.openssl
    pkgs.nix-unstable.ncurses
    pkgs.nix-unstable.stdenv.cc.cc.lib
    pkgs.nix-unstable.julia
  ];

  shellHook = ''
    export CPPFLAGS="-I${pkgs.nix-unstable.zlib.dev}/include -I${pkgs.nix-unstable.libffi.dev}/include -I${pkgs.nix-unstable.readline.dev}/include -I${pkgs.nix-unstable.bzip2.dev}/include -I${pkgs.nix-unstable.openssl.dev}/include"
    export CXXFLAGS="-I${pkgs.nix-unstable.zlib.dev}/include -I${pkgs.nix-unstable.libffi.dev}/include -I${pkgs.nix-unstable.readline.dev}/include -I${pkgs.nix-unstable.bzip2.dev}/include -I${pkgs.nix-unstable.openssl.dev}/include"
    export CFLAGS="-I${pkgs.nix-unstable.openssl.dev}/include"
    export LDFLAGS="-L${pkgs.nix-unstable.zlib.out}/lib -L${pkgs.nix-unstable.libffi.out}/lib -L${pkgs.nix-unstable.readline.out}/lib -L${pkgs.nix-unstable.bzip2.out}/lib -L${pkgs.nix-unstable.openssl.out}/lib"
    export PKG_CONFIG_PATH="${pkgs.nix-unstable.ncurses}/lib/pkgconfig:${pkgs.nix-unstable.libffi}/lib/pkgconfig:${pkgs.nix-unstable.readline}/lib/pkgconfig:${pkgs.nix-unstable.openssl}/lib/pkgconfig"
    export CONFIGURE_OPTS="-with-openssl=${pkgs.nix-unstable.openssl.dev}"
    export LD_LIBRARY_PATH=${
      pkgs.nix-unstable.lib.makeLibraryPath [ pkgs.nix-unstable.stdenv.cc.cc ]
    }
    export MLFLOW_S3_ENDPOINT_URL=https://s3-api.lan.aicampground.com
    export MLFLOW_TRACKING_URI=https://mlflow.lan.aicampground.com
    echo 🏕️ Welcome to the Campground
  '';
}
