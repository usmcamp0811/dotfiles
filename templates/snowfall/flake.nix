{
  description = "My Home Manager flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;
        snowfall = {
          meta = {
            name = "namespace-change-me";
            title = "PlaceHolder Title";
          };
          namespace = "namespace-change-me";
        };
      };
    in lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages =
          [ "python-2.7.18.6" "python-2.7.18.7" "qtwebkit-5.212.0-alpha4" ];
      };

      overlays = with inputs;
        [
          # Add your overlays here
        ];

      homes.modules = with inputs;
        [
          # your overlays here
        ];

      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.home-manager
        nix-rosetta-builder.darwinModules.default
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        }
      ];
      systems.modules.nixos = with inputs;
        [
          home-manager.nixosModules.home-manager
          # Add your system modules here
        ];
    };
}
