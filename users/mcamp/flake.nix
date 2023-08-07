{
  description = "Test";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-22.05";
    unstable.url = "github:nixos/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plusultra = {
      url = "github:jakehamilton/config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.unstable.follows = "unstable";
    };
  };

  outputs = { self, nixpkgs, home-manager, snowfall-lib, plusultra, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations = {
        mcamp = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          modules = [
            ({ pkgs, ... }: {
              imports = [
                ./home.nix
                plusultra.nixosModules.home-manager
              ];
              home.username = "mcamp";
              home.homeDirectory = "/home/mcamp";
              home.stateVersion = "22.11";
            })
          ];
        };
      };
    };
}

