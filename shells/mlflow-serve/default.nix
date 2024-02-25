{ mkShell
, pkgs
, inputs
, config
, lib
, system
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib.campground) override-meta;
  pkgs-unstable = inputs.unstable.legacyPackages.${system};

  # This is required if you get odd errors
  # read the https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md
  pypkgs-build-requirements = {
    pyjulia = [ "setuptools"];
    julia = [ "setuptools" ];
    juliapkg = [ "setuptools" ];
    urllib3 = [ "hatchling" ];
    juliacall = [ "setuptools" ];
    pandas = [ "versioneer" ];
    sphinxcontrib-jquery = [ "sphinx" "setuptools" ];
    gunicorn = ["setuptools-scm"];
    # contourpy = [ "mesonpy" ];
    # numpy = [ "setuptools" ];
  };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);

      })
    ) pypkgs-build-requirements
  );
  python-env = pkgs.poetry2nix.mkPoetryEnv  {
    projectDir = ./.;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true;
  };
in
pkgs-unstable.mkShell {
  buildInputs = [
   python-env 
   pkgs-unstable.gcc
   pkgs-unstable.libunistring
   pkgs-unstable.libidn2
   pkgs-unstable.tzdata
   pkgs-unstable.zlib
   pkgs-unstable.zlib.dev
   pkgs-unstable.readline
   pkgs-unstable.readline.dev
   pkgs-unstable.bzip2
   pkgs-unstable.bzip2.dev
   pkgs-unstable.ncurses
   pkgs-unstable.ncurses.dev
   pkgs-unstable.sqlite
   pkgs-unstable.sqlite.dev
   pkgs-unstable.openssl
   pkgs-unstable.openssl.dev
   pkgs-unstable.libuuid
   pkgs-unstable.libuuid.dev
   pkgs-unstable.gdbm
   pkgs-unstable.lzlib
   pkgs-unstable.tk
   pkgs-unstable.tk.dev
   pkgs-unstable.libffi
   pkgs-unstable.libffi.dev
   pkgs-unstable.expat
   pkgs-unstable.expat.dev
   pkgs-unstable.mailcap
   pkgs-unstable.xz
   pkgs-unstable.xz.dev
   pkgs-unstable.openssl
   pkgs-unstable.unzip
   pkgs-unstable.gnutar
   pkgs-unstable.wget
   pkgs-unstable.curl
   pkgs-unstable.gnugrep
   pkgs-unstable.gawk
   pkgs-unstable.gnused
   pkgs-unstable.pyenv
   pkgs-unstable.bashInteractive
   pkgs-unstable.gnumake
   pkgs-unstable.zlib
   pkgs-unstable.libffi
   pkgs-unstable.readline
   pkgs-unstable.bzip2
   pkgs-unstable.openssl
   pkgs-unstable.ncurses
   pkgs-unstable.stdenv.cc.cc.lib
   pkgs-unstable.julia
  ];

  shellHook = ''
    export CPPFLAGS="-I${pkgs-unstable.zlib.dev}/include -I${pkgs-unstable.libffi.dev}/include -I${pkgs-unstable.readline.dev}/include -I${pkgs-unstable.bzip2.dev}/include -I${pkgs-unstable.openssl.dev}/include"
    export CXXFLAGS="-I${pkgs-unstable.zlib.dev}/include -I${pkgs-unstable.libffi.dev}/include -I${pkgs-unstable.readline.dev}/include -I${pkgs-unstable.bzip2.dev}/include -I${pkgs-unstable.openssl.dev}/include"
    export CFLAGS="-I${pkgs-unstable.openssl.dev}/include"
    export LDFLAGS="-L${pkgs-unstable.zlib.out}/lib -L${pkgs-unstable.libffi.out}/lib -L${pkgs-unstable.readline.out}/lib -L${pkgs-unstable.bzip2.out}/lib -L${pkgs-unstable.openssl.out}/lib"
    export PKG_CONFIG_PATH="${pkgs-unstable.ncurses}/lib/pkgconfig:${pkgs-unstable.libffi}/lib/pkgconfig:${pkgs-unstable.readline}/lib/pkgconfig:${pkgs-unstable.openssl}/lib/pkgconfig"
    export CONFIGURE_OPTS="-with-openssl=${pkgs-unstable.openssl.dev}"
    export LD_LIBRARY_PATH=${pkgs-unstable.lib.makeLibraryPath [
      pkgs-unstable.stdenv.cc.cc
    ]}
    echo 🏕️ Welcome to the Campground
  '';
}
