{
  description = "Home Manager configuration of mcamp";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    campground-nvim.url = "gitlab:usmcamp0811/campground-nvim";

  };

  outputs = { self, nixpkgs, home-manager, nur, campground-nvim, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nvim = campground-nvim.default.${system}.default; # Access the nvim package from campground-nvim
    in {
      homeConfigurations."mcamp" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
        };
        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          ({ config, ... }: {
            nixpkgs.overlays = [
              nur.overlay
            ];
            programs.neovim = { # Configure Neovim with campground-nvim
              enable = true;
              package = nvim; # Use the nvim package from campground-nvim
            };
          })
          ./home.nix
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}


