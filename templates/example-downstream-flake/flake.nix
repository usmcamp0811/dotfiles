{
  description = "Example Downstream Nix Config (downstream of fmf)";

  inputs = {
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/release-25.11";

    fmf.url = "gitlab:usmcamp0811/dotfiles/nixos";

    # Snowfall lib
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Disko - Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    # Short alias like `campgroundInputs` in the ATA flake
    fmfInputs = inputs.fmf.inputs or {};

    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;
      snowfall = {
        meta = {
          name = "campground";
          title = "Downstream Nix Config";
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
          "gradle-7.6.6"
          "qtwebkit-5.212.0-alpha4"
        ];
      };

      # Reuse overlays from fmf (if any)
      overlays =
        if inputs.fmf ? overlays
        then builtins.attrValues inputs.fmf.overlays
        else [];

      # Reuse Home Manager modules from fmf
      homes.modules =
        if inputs.fmf ? homeModules
        then builtins.attrValues inputs.fmf.homeModules
        else [];

      # Darwin systems: HM + whatever else you add later
      systems.modules.darwin = [
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        }
      ];

      systems.modules.nixos =
        [
          # Home Manager
          inputs.home-manager.nixosModules.home-manager

          # The same stack your fmf flake uses in its systems.modules.nixos
          fmfInputs.nixtheplanet.nixosModules.macos-ventura
          fmfInputs.vault-service.nixosModules.nixos-vault-service
          fmfInputs.nix-topology.nixosModules.default
          fmfInputs.catppuccin.nixosModules.catppuccin
          fmfInputs.flakeforge.nixosModules.flakeforge
          fmfInputs.funkwhale.nixosModules.default
          fmfInputs.authentik-nix.nixosModules.default
          fmfInputs.nixos-router.nixosModules.default
          fmfInputs.impermanence.nixosModules.impermanence
          fmfInputs.microvm.nixosModules.host
        ]
        # All Crystal Forge modules, like ATA does with campgroundInputs.crystal-forge
        ++ (lib.attrValues fmfInputs.crystal-forge.nixosModules)
        # All top-level fmf nixosModules (equivalent to inputs.campground.nixosModules)
        ++ (lib.attrValues inputs.fmf.nixosModules);

      # Reuse fmf's deploy helper (mirrors `lib.campground.mkDeploy` in ATA flake)
      deploy = lib.fmf.mkDeploy {inherit (inputs) self;};
    };
}
