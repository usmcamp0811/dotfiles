{
  description = "Campground Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    #nuenv
    nuenv.url = "github:DeterminateSystems/nuenv";

    # nixvim
    nix-vim.url = "github:nix-community/nixvim";

    # Nixery
    nixery-flake = {
      type = "github";
      owner = "tazjin";
      repo = "nixery";
      flake = false;
    };

    # macOS Support (master)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";

    bibata-cursors = {
      url = "github:suchipi/Bibata_Cursor";
      flake = false;
    };

    # Hyprland
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "unstable";
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "unstable";
    };

    # Hyprland user contributions flake
    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "unstable";
    };

    gBar.url = "github:scorpion-26/gBar";

    # NixPkgs-Wayland
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "unstable";
    };

    # Binary Cache
    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "unstable";
      # inputs.nixpkgs-stable.follows = "nixpkgs";
    };

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
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager (release-23.05)
    home-manager.url = "github:nix-community/home-manager/release-23.11";
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

    nur.url = "github:nix-community/NUR";

    # nix2sbom.url = "https://flakehub.com/f/louib/nix2sbom/0.1.97.tar.gz";
    nix2sbom.url = "github:louib/nix2sbom";
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
      # inputs.nixpkgs.follows = "unstable";
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

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "unstable";
    };

    # Run unpatched dynamically compiled binaries
    nix-ld-rs = {
      url = "github:nix-community/nix-ld-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    julia2nix.url = "github:JuliaCN/Julia2Nix.jl";
    dream2nix.url = "github:nix-community/dream2nix";
    scientific-fhs = {
      url = "github:usmcamp0811/scientific-fhs/add-poetry";
      # url = "path:/home/mcamp/code/scientific-fhs";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-output-monitor.url = "github:maralorn/nix-output-monitor";

    dataflow2nix.url = "github:GTrunSec/dataflow2nix";

    nixpkgs-julia.url = "github:NixOS/nixpkgs/?ref=refs/pull/225513/head";
  };

  outputs = inputs:
    let
      inherit (inputs) deploy-rs;
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

    in lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages =
          [ "python-2.7.18.6" "python-2.7.18.7" "qtwebkit-5.212.0-alpha4" ];
      };

      overlays = with inputs; [
        icehouse.overlays."package/icehouse"
        flake.overlays."package/flake"
        attic.overlays.default
        devshell.overlays.default
        nix-ld-rs.overlays.default
        julia2nix.overlays.default
        nuenv.overlays.default
        nur.overlay
        nix-snapshotter.overlays.default
        poetry2nix.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
        vault-service.nixosModules.nixos-vault-service
        dataflow2nix.nixosModules.airflow
        # scientific-fhs.nixosModules.default
      ];

      systems.hosts.butler.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-p1
        nixos-hardware.nixosModules.lenovo-thinkpad-p53
      ];

      # Fixed bug in Amazon image builder: https://github.com/nix-community/nixos-generators/issues/150
      systems.hosts.base.modules =
        [ ({ ... }: { amazonImage.sizeMB = 32 * 1024; }) ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks = builtins.mapAttrs
        (_system: deploy-lib:
          deploy-lib.deployChecks inputs.self.deploy)
        deploy-rs.lib
        // {
          mlflow-test = inputs.nixpkgs.legacyPackages.x86_64-linux.nixosTest {
            name = "mlflow-test";
            nodes = {
              machine = { ... }: {
                environment.systemPackages = [ lib.campground.mlflow ];
              };
            };
            testScript = ''
              startAll;
              machine.waitUntilSucceeds("mlflow --help");
              machine.succeed("mlflow --help");
            '';
          };
        };

      templates = {
        basic = {
          path = ./templates/basic;
          description = "a very basic flake";
        };
        shell-container = {
          path = ./templates/shell-container;
          description = "An example Shell that is also a Docker Container";
        };
        new-system = {
          path = ./templates/new-system;
          description = "A new system config to get things started.";
        };
      };

    };

}

