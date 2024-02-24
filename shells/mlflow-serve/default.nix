{ mkShell
, pkgs
, config
, lib
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib.campground) override-meta;

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
pkgs.mkShell {
  buildInputs = [
   python-env 
   pkgs.gcc
   pkgs.libunistring
   pkgs.libidn2
   pkgs.tzdata
   pkgs.zlib
   pkgs.zlib.dev
   pkgs.readline
   pkgs.readline.dev
   pkgs.bzip2
   pkgs.bzip2.dev
   pkgs.ncurses
   pkgs.ncurses.dev
   pkgs.sqlite
   pkgs.sqlite.dev
   pkgs.openssl
   pkgs.openssl.dev
   pkgs.libuuid
   pkgs.libuuid.dev
   pkgs.gdbm
   pkgs.lzlib
   pkgs.tk
   pkgs.tk.dev
   pkgs.libffi
   pkgs.libffi.dev
   pkgs.expat
   pkgs.expat.dev
   pkgs.mailcap
   pkgs.xz
   pkgs.xz.dev
   pkgs.openssl
   pkgs.unzip
   pkgs.gnutar
   pkgs.wget
   pkgs.curl
   pkgs.gnugrep
   pkgs.gawk
   pkgs.gnused
   pkgs.pyenv
   pkgs.bashInteractive
   pkgs.gnumake
   pkgs.zlib
   pkgs.libffi
   pkgs.readline
   pkgs.bzip2
   pkgs.openssl
   pkgs.ncurses
   pkgs.stdenv.cc.cc.lib
   pkgs.julia
  ];

  shellHook = ''
    export CPPFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include"
    export CXXFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include"
    export CFLAGS="-I${pkgs.openssl.dev}/include"
    export LDFLAGS="-L${pkgs.zlib.out}/lib -L${pkgs.libffi.out}/lib -L${pkgs.readline.out}/lib -L${pkgs.bzip2.out}/lib -L${pkgs.openssl.out}/lib"
    export PKG_CONFIG_PATH="${pkgs.ncurses}/lib/pkgconfig:${pkgs.libffi}/lib/pkgconfig:${pkgs.readline}/lib/pkgconfig:${pkgs.openssl}/lib/pkgconfig"
    export CONFIGURE_OPTS="-with-openssl=${pkgs.openssl.dev}"
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      pkgs.stdenv.cc.cc
    ]}
    echo 🏕️ Welcome to the Campground
  '';
}
