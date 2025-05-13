{
  description = "Simple flake exporting a Rust package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in {
        packages.default =
          import ./packages/hello-rust/default.nix { inherit lib pkgs; };
        packages.hello-nix =
          import ./packages/hello-rust/default.nix { inherit lib pkgs; };
      });
}
