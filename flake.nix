{
  description = "Campground Config";

  inputs = {
    authentik-nix.url = "github:nix-community/authentik-nix";
    terranix.url = "github:terranix/terranix";
    old-nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    # "github:nixos/nixpkgs/release-24.05/797f7dc49e0bc7fab4b57c021cdf68f595e47841";
    pyarrow.url =
      "github:nixos/nixpkgs/e8b4c13b8d206f4b01e95499aa7425765a79513e";
    hyprland-works-here.url =
      "github:nixos/nixpkgs/219951b495fc2eac67b1456824cc1ec1fd2ee659";
    # TODO: Switch back to unstable branch when the node fix gets merged
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    immich-fix.url =
      "github:nixos/nixpkgs/1925c603f17fc89f4c8f6bf6f631a802ad85d784";
    #nuenv
    nuenv.url = "github:DeterminateSystems/nuenv";

    # nixvim
    # nix-vim.url =
    #   "github:nix-community/nixvim/123c102a13d1aad053984af08ecc34e807e1f69d";
    nix-vim = {
      url = "github:nix-community/nixvim/main";
      inputs.nixpkgs.follows = "unstable";
    };

    # Nixery
    nixery-flake = {
      type = "github";
      owner = "tazjin";
      repo = "nixery";
      flake = false;
    };

    flakeforge = {
      url = "github:usmcamp0811/flakeforge";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-cli.url = "github:water-sucks/nixos";

    # macOS Support (master)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "unstable";

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

    nix-topology.url = "github:oddlama/nix-topology";
    nixpkgs-python.url = "github:cachix/nixpkgs-python";

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
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Vault Integration

    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "unstable";

    updated-ollama.url = "github:nixos/nixpkgs";
    # Flake Hygiene
    # flake-checker = {
    #   url = "github:usmcamp0811/flake-checker";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # Run unpatched dynamically compiled binaries
    nix-ld.url = "github:nix-community/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "unstable";

    nur.url = "github:nix-community/NUR";

    # nix2sbom.url = "https://flakehub.com/f/louib/nix2sbom/0.1.97.tar.gz";
    nix2sbom.url = "github:louib/nix2sbom";
    nix2sbom.inputs.nixpkgs.follows = "unstable";

    sbomnix = {
      url = "github:tiiuae/sbomnix";
      inputs.nixpkgs.follows = "unstable";
    };

    mlflow-works.url =
      "gitlab:usmcamp0811/dotfiles/38739f362e9c8e27880c0835f8db4a4866a61337";

    nix-snapshotter = {
      url = "github:yu-re-ka/nix-snapshotter/update";
      # url = "github:pdtpartners/nix-snapshotter";
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

    campground-nvim.url = "gitlab:usmcamp0811/campground-nvim";
    # campground-jupyterlab.url = "gitlab:usmcamp0811/campground-jupyter-lab";
    # campground-jupyterlab.inputs.nixpkgs.follows = "unstable";

    campground-packages.url = "gitlab:usmcamp0811/campground-packages";

    # Backup management
    poetry2nix = {
      url = "github:TyberiusPrime/poetry2nix/pyarrow_fix";
      inputs.nixpkgs.follows = "unstable";
    };

    # Run unpatched dynamically compiled binaries
    nix-ld-rs = {
      url = "github:nix-community/nix-ld-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dream2nix.url = "github:nix-community/dream2nix";
    scientific-fhs = {
      url = "github:usmcamp0811/scientific-fhs/pass-python-env-in";
      # url = "path:/home/mcamp/code/scientific-fhs";
      # inputs.nixpkgs.follows = "unstable";
    };

    nix-output-monitor.url = "github:maralorn/nix-output-monitor";

    dataflow2nix.url = "github:GTrunSec/dataflow2nix";

    compose2nix.url = "github:aksiksi/compose2nix";
    compose2nix.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    nix-ai.url = "github:nixified-ai/flake";
    neorg-overlay = {
      url = "github:nvim-neorg/nixpkgs-neorg-overlay";
      inputs.nixpkgs.follows = "unstable";
    };

    # nix-health.url = "github:juspay/nix-health?dir=module";
    crowdsec = {
      url = "git+https://codeberg.org/kampka/nix-flake-crowdsec.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    funkwhale.url = "github:usmcamp0811/funkwhale-flake";
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
      # system = "x86_64-linux";
      # pkgs = import nixpkgs {
      #   inherit system;
      # };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.6"
          "python-2.7.18.7"
          "qtwebkit-5.212.0-alpha4"
          "python3.11-apache-airflow-2.7.3"
        ];
      };

      overlays = with inputs; [
        flake.overlays."package/flake"
        attic.overlays.default
        devshell.overlays.default
        nix-ld-rs.overlays.default
        nuenv.overlays.default
        nur.overlay
        nix-snapshotter.overlays.default
        poetry2nix.overlays.default
        nix-topology.overlays.default
        funkwhale.overlays.default
        # neorg-overlay.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
        vault-service.nixosModules.nixos-vault-service
        dataflow2nix.nixosModules.airflow
        nix-topology.nixosModules.default
        catppuccin.nixosModules.catppuccin
        flakeforge.nixosModules.flakeforge
        crowdsec.nixosModules.crowdsec
        funkwhale.nixosModules.default
        authentik-nix.nixosModules.default
        # "${unstable}/nixos/modules/services/web-apps/immich.nix"
        # "${unstable}/nixos/modules/services/databases/chromadb.nix"
        # unstable.nixosModules.redis
        # nixos-cli.nixosModules.nixos-cli
        # nix-health.flakeModule
        # scientific-fhs.nixosModules.default
      ];

      # Temporary, immich is not in 24.05
      # systems.hosts.webb.modules = with inputs;
      #   [
      #     ({ ... }: {
      #       disabledModules = [ "services/databases/redis.nix" ];
      #       imports = [
      #         "${unstable}/nixos/modules/services/web-apps/immich.nix"
      #         "${unstable}/nixos/modules/services/databases/redis.nix"
      #       ];
      #     })
      #   ];
      systems.hosts.butler.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-p1
        nixos-hardware.nixosModules.lenovo-thinkpad-p53
      ];

      # Fixed bug in Amazon image builder: https://github.com/nix-community/nixos-generators/issues/150
      systems.hosts.base.modules =
        [ ({ ... }: { amazonImage.sizeMB = 32 * 1024; }) ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks = builtins.mapAttrs
        (_system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy)
        deploy-rs.lib;

      outputs-builder = channels: {
        # this needs to be `hooks` not `checks` because `checks` will get run with `deploy` and 
        # which will break `deploy`. 
        hooks.pre-commit-check =
          inputs.pre-commit-hooks.lib.${channels.nixpkgs.system}.run {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
              # flake8.enable = true;
              # markdownlint.enable = true;
              # yamllint.enable = true;
              # deadnix.enable = true;
            };
          };
        # checks.mlflow-test = channels.nixpkgs.nixosTest {
        #   name = "mlflow-test";
        #   nodes = {
        #     machine =
        #       { inputs, ... }: {
        #         environment.systemPackages = [ inputs.self.mlflow-server ];
        #       };
        #   };
        #   testScript = ''
        #     startAll;
        #     machine.waitUntilSucceeds("mlflow --help");
        #     machine.succeed("mlflow --help");
        #   '';
        # };

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
        flink-job = {
          path = ./templates/flink-job;
          description = "An example of how to use my mkPyFlinkDerivation";
        };
        new-azure-vm = {
          path = ./templates/new-azure-vm;
          description = "A template for a new azure vm";
        };
      };
    };
}
