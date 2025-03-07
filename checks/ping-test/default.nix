{ pkgs, ... }:

pkgs.callPackage ./test.nix { inherit pkgs; }
