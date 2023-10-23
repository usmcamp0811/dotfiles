{
  description = "Campground Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # macOS Support (master)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";

    campground-nvim.url = "gitlab:usmcamp0811/campground-nvim";
    # campground-nvim.url = "path:/home/mcamp/code/campground-nvim";

    # Snowfall Lib
    snowfall-lib.url = "github:snowfallorg/lib";
    # snowfall-lib.url = "path:/home/mcamp/code/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Flake
    flake.url = "github:snowfallorg/flake";
    flake.inputs.nixpkgs.follows = "unstable";
    
    # Comma
    comma.url = "github:nix-community/comma";
    comma.inputs.nixpkgs.follows = "unstable";

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

    vault-service = { url = "github:DeterminateSystems/nixos-vault-service"; 
    inputs.nixpkgs.follows = "nixpkgs"; }; 

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

    nur.url = "github:nix-community/NUR";

    nix2sbom.url = "https://flakehub.com/f/louib/nix2sbom/0.1.97.tar.gz";
    nix2sbom.inputs.nixpkgs.follows = "unstable";

    sbomnix = {
      url = "github:tiiuae/sbomnix";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-snapshotter = {
      url = "github:pdtpartners/nix-snapshotter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    technofab = {
      url = "gitlab:TECHNOFAB/nix-packages";
      inputs.nixpkgs.follows = "unstable";
    };

    # GPG default configuration
    gpg-base-conf = {
      url = "github:drduh/config";
      flake = false;
    };

    campground-jupyterlab.url = "gitlab:usmcamp0811/campground-jupyter-lab";
    campground-jupyterlab.inputs.nixpkgs.follows = "unstable";

    campground-packages.url = "gitlab:usmcamp0811/campground-packages";

    # Backup management
    icehouse = {
      url = "github:snowfallorg/icehouse";
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
          "python-2.7.18.7"
        ];
      };

      overlays = with inputs; [
          icehouse.overlays."package/icehouse"
				  flake.overlays."package/flake"
          nur.overlay
      ];

      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
        vault-service.nixosModules.nixos-vault-service
      ];

      # systems.modules = with inputs; [
      #   campground-nvim.nixosModules.nixvim
      # ];
      
      #TODO: Move this into the actual system config?
      systems.hosts.ata-xps.modules = with inputs; [
        nixos-hardware.nixosModules.dell-xps-13-7390

      ];

      systems.hosts.ata-nuc.modules = with inputs; [
        nixos-hardware.nixosModules.intel-nuc-8i7beh

      ];

      #TODO: Move this into the actual system config?
      systems.hosts.butler.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-p1
        nixos-hardware.nixosModules.lenovo-thinkpad-p53
      ];

      # Fixed bug in Amazon image builder: https://github.com/nix-community/nixos-generators/issues/150
      systems.hosts.base.modules = [({...}: { amazonImage.sizeMB = 16 * 1024; })];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks =
        builtins.mapAttrs
          (system: deploy-lib:
            deploy-lib.deployChecks inputs.self.deploy)
          inputs.deploy-rs.lib;
    };
}

