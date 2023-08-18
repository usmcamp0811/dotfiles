{
  description = "Campground Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    campground-nvim.url = "gitlab:usmcamp0811/campground-nvim";

    # Snowfall Lib
    snowfall-lib.url = "github:snowfallorg/lib/dev";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Flake
    flake.url = "github:snowfallorg/flake";
    flake.inputs.nixpkgs.follows = "unstable";


    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Generate System Images
    nixos-generators.url =
      "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager (release-23.05)
    home-manager.url =
      "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Vault Integration
    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "unstable";

    # Flake Hygiene
    flake-checker = {
      url = "github:DeterminateSystems/flake-checker";
      inputs.nixpkgs.follows = "unstable";
    };

    # Run unpatched dynamically compiled binaries
    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "unstable";
  };

  outputs = inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          meta = {
            name = "campground";
            title = "AI Campground";
          };
          namespace = "campground";
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.6"
        ];
      };
      package-namespace = "campground";

      overlays = [
        # (final: prev: {
        #   neovim = inputs.campground-nvim.packages.x86_64-linux.default;
        # })
        inputs.flake.overlay
      ];
     # overlays = with inputs; [
     # ];

      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
        vault-service.nixosModules.nixos-vault-service
        campground-nvim.nixosModules.nvim
      ];

      # systems.modules = with inputs; [
      #   campground-nvim.nixosModules.nixvim
      # ];
      #
      #TODO: Move this into the actual system config?
      systems.hosts.ata-xps.modules = with inputs; [
        nixos-hardware.nixosModules.dell-xps-13-7390

      ];

      #TODO: Move this into the actual system config?
      # systems.hosts.butler.modules = with inputs; [
      #   nixos-hardware.nixosModules.lenovo-thinkpad-p1
      # ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks =
        builtins.mapAttrs
          (system: deploy-lib:
            deploy-lib.deployChecks inputs.self.deploy)
          inputs.deploy-rs.lib;
    };
}

