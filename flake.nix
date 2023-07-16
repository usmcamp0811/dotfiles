{
  description = "Campground Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Snowfall Lib
    snowfall-lib.url = "github:snowfallorg/lib/dev";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Flake
    flake.url = "github:snowfallorg/flake";
    flake.inputs.nixpkgs.follows = "unstable";

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

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

    # secrets management, lock with git commit at 2023/5/15
    # agenix.url = "github:ryantm/agenix/db5637d10f797bb251b94ef9040b237f4702cde3";

  };

  outputs = inputs:
    let
      # mysecrets = builtins.fetchGit {
      #   url = "git@gitlab.com:usmcamp0811/campground-secrets.git";
      #   ref = "master"; 
      #   rev = "955a4322b58a027a6eba938150452b485153b7dd"; 
      # };

      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;
      };
    in
    lib.mkFlake {
      package-namespace = "campground";

      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
      ];

      systems.modules = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
        # attic.nixosModules.atticd
        vault-service.nixosModules.nixos-vault-service
        # ./secrets/default.nix
      ];

      systems.hosts.ata-xps.modules = with inputs; [
        # See https://github.com/NixOS/nixos-hardware/tree/master/dell/xps/13-7390
        nixos-hardware.nixosModules.dell-xps-13-7390
      ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks =
        builtins.mapAttrs
          (system: deploy-lib:
            deploy-lib.deployChecks inputs.self.deploy)
          inputs.deploy-rs.lib;
    };

}
