{
  description =
    "Simple NixOS System Flake with overlays and packages using configuration.nix";

  inputs = {
    # Import nixpkgs from the NixOS 24.11 release
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";

    # flake-utils provides helpers for multi-system support
    flake-utils.url = "github:numtide/flake-utils";

    # Matt's neovim config for demo
    campground.url = "gitlab:usmcamp0811/dotfiles";
  };

  outputs = { self, nixpkgs, flake-utils, campground, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import nixpkgs with overlays enabled
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
        # Packages can be exported in here
      in {
        # Provide a default package (example stub)
        # packages.myPackage = pkgs.myPackage;
      }) //
    # System Config inside of this block
    {
      # Define an overlay that adds a stub package
      overlays.default = final: prev: {
        # Example stub overlay: expose hello as myPackage
        campfetch = self.inputs.campground.packages.${final.system}.campfetch;
      };

      # Define a NixOS configuration using configuration.nix
      nixosConfigurations.ata-machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          {
            # Pass overlay to NixOS system
            nixpkgs.overlays = [ self.overlays.default ];
          }
        ];
      };
      nixosConfigurations.nix-hour = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          {
            # Pass overlay to NixOS system
            nixpkgs.overlays = [ self.overlays.default ];
          }
        ];
      };
    };
}
