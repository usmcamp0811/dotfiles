{
  description = "A Shell that is alos a Container";

  # Specifies the inputs for this flake, such as nixpkgs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-julia.url = "github:NixOS/nixpkgs/?ref=refs/pull/225513/head";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  # Use flake-utils to simplify flake outputs for multiple systems
  outputs = { self, julia2nix, poetry2nix, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            poetry2nix.overlays.default
          ];
          config = {
            allowUnfree = true; 
          };
        };
        julia-env = pkgs.julia.withPackages [ "Pluto" "FileIO" "JLD2" "PythonCall"];
        shell-env = pkgs.buildEnv rec { 
          name = "shell-env";       
          paths = [
             julia-env
            ];
        };
        pluto = pkgs.writeShellScriptBin "pluto" ''
          ${julia-env}/bin/julia -e "using Pluto; Pluto.run()"
        '';
        shell-img = pkgs.dockerTools.buildNixShellImage {
          name = "shell-container" ;
          tag = "latest";
          drv = shell;
          command = ''${pluto}/bin/pluto'';
        };
        shell = pkgs.mkShell {
            buildInputs = [ (shell-env) ];
            shellHook = ''
            echo "Example Shell Container with Pluto.jl" | ${pkgs.figlet}/bin/figlet
            '';
          };
      in
      {
        packages = {
          container = shell-img;
          pluto = pluto;
        };

        devShells.default = shell;
      }
    );
}

