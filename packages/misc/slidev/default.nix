{ pkgs, ... }:
let
  nodePackages = pkgs.callPackage ./yarn.nix { };

  bootstrap = pkgs.writeShellScriptBin "bootstrap" ''
    echo "Bootstrapping Slidev environment..."
    ${pkgs.yarn}/bin/yarn install
    echo "Slidev environment bootstrapped successfully!"
  '';

  update = pkgs.writeShellScriptBin "update" ''
    ${pkgs.yarn}/bin/yarn add @slidev/cli@latest
    ${pkgs.yarn2nix}/bin/yarn2nix > yarn.nix
  '';

  start = pkgs.writeShellScriptBin "start" ''
    ${pkgs.yarn}/bin/yarn slidev --remote
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "slidev";
  version = "0.49.29";
  src = ./.;

  buildInputs = [
    pkgs.nodejs
    pkgs.yarn
    pkgs.yarn2nix
    bootstrap
    update
    start
  ];

  shellHook = ''
    export PATH=$PATH:${builtins.toString ./.}/node_modules/.bin
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
}
