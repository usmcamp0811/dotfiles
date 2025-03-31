{
  description = "Basic NixOS Flake for one x86_64 system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell { buildInputs = [ pkgs.hello ]; };
      }) // {
        nixosConfigurations.my-x86 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ({ pkgs, ... }: {
              imports = [ ./configurations.nix ];
              networking.hostName = "my-x86";
              users.users.root.initialPassword = "root";
              services.openssh.enable = true;
            })
          ];
        };
      };
}
