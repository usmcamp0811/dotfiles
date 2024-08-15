{ pkgs, ... }:
let
  src = ./.;

  build-image = pkgs.writeShellScriptBin "build" ''
    AUTHORIZED_KEY=${"1:-" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler"}
    ${pkgs.docker}/bin/docker build -f ${src}/Dockerfile -t nix-build --build-arg AUTHORIZED_KEY="$AUTHORIZED_KEY" .
  '';

  start-builder = pkgs.writeShellScriptBin "start-builder" ''
    ${pkgs.docker}/bin/docker -f ${src}/Dockerfile -t nix-build .
  '';
in
build-image
