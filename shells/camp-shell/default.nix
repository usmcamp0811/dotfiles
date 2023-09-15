{
    # Snowfall Lib provides a customized `lib` instance with access to your flake's library
    # as well as the libraries available from your flake's inputs.
    lib,
    # You also have access to your flake's inputs.
    inputs,

    # All other arguments come from NixPkgs. You can use `pkgs` to pull shells or helpers
    # programmatically or you may add the named attributes as arguments here.
    pkgs,
    stdenv,
    flake-utils,
    devshells,
    ...
}:

stdenv.mkDerivation {
  name = "camp-shell";
  buildInputs = [
    pkgs.git
    pkgs.zsh
    pkgs.tmux
    pkgs.haskellPackages.ghc
    pkgs.python3
    pkgs.nodejs
    pkgs.jq
  ];
}
