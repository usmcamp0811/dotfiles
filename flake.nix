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
        inherit system pkgs;
        username = "mcamp";
        homeDirectory = "/home/mcamp";
        configuration = {
          imports = [
            ./users/mcamp/home.nix
          ];
        };
      };
    };
    nixosConfigurations = {
      butler = lib.nixosSystem {
        inherit system;

        modules = [
          ./system/configuration.nix
        ];
      };
      nixos = lib.nixosSystem {
        inherit system;

        modules = [
          ./system/configuration.nix
        ];
      };
    };
  };

}

