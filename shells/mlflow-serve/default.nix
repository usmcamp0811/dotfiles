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
  nix-unstable = inputs.unstable.legacyPackages.${system};

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
nix-unstable.mkShell {
  buildInputs = [
   python-env 
   nix-unstable.gcc
   nix-unstable.libunistring
   nix-unstable.libidn2
   nix-unstable.tzdata
   nix-unstable.zlib
   nix-unstable.zlib.dev
   nix-unstable.readline
   nix-unstable.readline.dev
   nix-unstable.bzip2
   nix-unstable.bzip2.dev
   nix-unstable.ncurses
   nix-unstable.ncurses.dev
   nix-unstable.sqlite
   nix-unstable.sqlite.dev
   nix-unstable.openssl
   nix-unstable.openssl.dev
   nix-unstable.libuuid
   nix-unstable.libuuid.dev
   nix-unstable.gdbm
   nix-unstable.lzlib
   nix-unstable.tk
   nix-unstable.tk.dev
   nix-unstable.libffi
   nix-unstable.libffi.dev
   nix-unstable.expat
   nix-unstable.expat.dev
   nix-unstable.mailcap
   nix-unstable.xz
   nix-unstable.xz.dev
   nix-unstable.openssl
   nix-unstable.unzip
   nix-unstable.gnutar
   nix-unstable.wget
   nix-unstable.curl
   nix-unstable.gnugrep
   nix-unstable.gawk
   nix-unstable.gnused
   nix-unstable.pyenv
   nix-unstable.bashInteractive
   nix-unstable.gnumake
   nix-unstable.zlib
   nix-unstable.libffi
   nix-unstable.readline
   nix-unstable.bzip2
   nix-unstable.openssl
   nix-unstable.ncurses
   nix-unstable.stdenv.cc.cc.lib
   nix-unstable.julia
  ];

  shellHook = ''
    export CPPFLAGS="-I${nix-unstable.zlib.dev}/include -I${nix-unstable.libffi.dev}/include -I${nix-unstable.readline.dev}/include -I${nix-unstable.bzip2.dev}/include -I${nix-unstable.openssl.dev}/include"
    export CXXFLAGS="-I${nix-unstable.zlib.dev}/include -I${nix-unstable.libffi.dev}/include -I${nix-unstable.readline.dev}/include -I${nix-unstable.bzip2.dev}/include -I${nix-unstable.openssl.dev}/include"
    export CFLAGS="-I${nix-unstable.openssl.dev}/include"
    export LDFLAGS="-L${nix-unstable.zlib.out}/lib -L${nix-unstable.libffi.out}/lib -L${nix-unstable.readline.out}/lib -L${nix-unstable.bzip2.out}/lib -L${nix-unstable.openssl.out}/lib"
    export PKG_CONFIG_PATH="${nix-unstable.ncurses}/lib/pkgconfig:${nix-unstable.libffi}/lib/pkgconfig:${nix-unstable.readline}/lib/pkgconfig:${nix-unstable.openssl}/lib/pkgconfig"
    export CONFIGURE_OPTS="-with-openssl=${nix-unstable.openssl.dev}"
    export LD_LIBRARY_PATH=${nix-unstable.lib.makeLibraryPath [
      nix-unstable.stdenv.cc.cc
    ]}
    export MLFLOW_S3_ENDPOINT_URL=https://s3-api.lan.aicampground.com
    export MLFLOW_TRACKING_URI=https://mlflow.lan.aicampground.com
    echo 🏕️ Welcome to the Campground
  '';
}
