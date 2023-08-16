{
  description = "Home Manager configuration of mcamp";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    campground-nvim.url = "gitlab:usmcamp0811/campground-nvim";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, home-manager, campground-nvim, nur, ... }: {
    homeConfigurations = {
      mcamp = let
        system = "x86_64-linux";
        overlay = [
          (final: prev: {
            neovim = campground-nvim.packages.${system}.default;
          })
          nur.overlay
        ];
        pkgs = import nixpkgs {
          inherit system;
          overlays = overlay;
        };
      in home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
        ];
      };
    };
  };
}

