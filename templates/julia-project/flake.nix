{
  description = "Simple Julia Development Shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    devShells.default = forAllSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
        julia-env = pkgs.julia.withPackages [ "Pluto" "PythonCall" ];
      in pkgs.mkShell {
        name = "devshell";
        buildInputs = with pkgs; [ git nixfmt direnv nixpkgs-fmt julia-env ];
        shellHook = ''
          echo "Welcome to your development shell!"
        '';
      });
  };

  nixConfig = { extra-experimental-features = [ "nix-command" "flakes" ]; };
}
