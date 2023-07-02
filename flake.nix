{
  description = "The Campground Config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.11";

    /* nur = import (builtins.fetchTarball { */
    /*   url = "https://github.com/nix-community/NUR/archive/master.tar.gz"; */
    /*   sha256 = "0r155kmzc0zmm28par1qvz7fc40qgdjaf5mi31a3ib1kwfi12f8r"; */
    /* })  */

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }: 
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

    lib = nixpkgs.lib;

  in {
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
