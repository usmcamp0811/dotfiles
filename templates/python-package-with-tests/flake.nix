{
  description = "Simple flake exporting a Rust package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
      };
    };
  };
  outputs = { self, uv2nix, pyproject-nix, pyproject-build-systems, nixpkgs
    , flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        hello-nix = import ./packages/example-python/default.nix {
          inherit uv2nix pyproject-nix pyproject-build-systems lib pkgs;
        };
      in {
        packages = {
          default = hello-nix.default;
          hello-nix = hello-nix.default;
          python = hello-nix.python;
        };
        checks = {
          inherit (hello-nix.pythonSets.${system}.example-python.passthru.tests)
            pytest;
        };
      });
}
