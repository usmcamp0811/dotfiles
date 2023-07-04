{
  description = "The Campground Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.11";

    nur.url = "github:nix-community/NUR";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nur, ... }: 
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

    lib = nixpkgs.lib;

    nur-no-pkgs = import (nur + "/repos.json");

    nur-pkgs = { pkgs ? import nixpkgs {} }:
      let
        callPackage = pkgs.lib.callPackageWith pkgs;
      in
        pkgs.lib.mapAttrs (_: callPackage) nur-no-pkgs;

  in {
    homeManagerConfigurations = {
      mcamp = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          { config, lib, pkgs, ... }: {
            imports = [ ./users/mcamp/home.nix ];
            home-manager.users.mcamp = { inherit pkgs lib; dotfiles = self.dotfiles; };
          }
          {
            home = {
              username = "mcamp";
              homeDirectory = "/home/mcamp";
              stateVersion = "23.05";
            };
          }
        ];
      };
    };

    nixosConfigurations = {
      butler = lib.nixosSystem {
        inherit system;

        modules = [
          ./system/configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };
      nixos = lib.nixosSystem {
        inherit system;

        modules = [
          ./system/configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };
    };

    dotfiles = self.mkPath {
      path = ./config;
    };
  };
}

