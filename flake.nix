{
  description = "Campground Config";

  inputs = {
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";

    crystal-forge = {
      url = "git+ssh://git@gitlab.com/crystal-forge/crystal-forge";
      inputs.nixpkgs.follows = "unstable";
    };

    zig2nix.url = "github:Cloudef/zig2nix";
    nixtheplanet.url = "github:Doc-Steve/NixThePlanet";
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
    authentik-nix.url = "github:marcelcoding/authentik-nix";
    # authentik-nix.inputs.nixpkgs.follows = "unstable";
    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    old-nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    pyarrow.url = "github:nixos/nixpkgs/e8b4c13b8d206f4b01e95499aa7425765a79513e";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    #nuenv
    nuenv.url = "github:DeterminateSystems/nuenv";
    nuenv.inputs.nixpkgs.follows = "nixpkgs";

    # Nixery
    nixery-flake = {
      type = "github";
      owner = "tazjin";
      repo = "nixery";
      flake = false;
    };

    flakeforge = {
      url = "github:usmcamp0811/flakeforge";
      inputs.nixpkgs.follows = "unstable";
    };

    nixos-cli.url = "github:water-sucks/nixos";
    nixos-cli.inputs.nixpkgs.follows = "nixpkgs";

    # macOS Support (master)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "unstable";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

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
    nix-topology.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-python.url = "github:cachix/nixpkgs-python";
    nixpkgs-python.inputs.nixpkgs.follows = "nixpkgs";

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "unstable";
    };

    # Hyprland user contributions flake
    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gBar.url = "github:scorpion-26/gBar";
    gBar.inputs.nixpkgs.follows = "nixpkgs";

    # NixPkgs-Wayland
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snowfall Lib
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Flake
    flake.url = "github:snowfallorg/flake";
    flake.inputs.nixpkgs.follows = "nixpkgs";

    # Comma
    comma.url = "github:nix-community/comma";
    comma.inputs.nixpkgs.follows = "unstable";

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Generate System Images
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager (release-24.11)
    # home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Vault Integration

    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "unstable";

    updated-ollama.url = "github:nixos/nixpkgs/27dbbeec4f904960751678f949b22cf5aa3791d9";

    # Run unpatched dynamically compiled binaries
    nix-ld.url = "github:nix-community/nix-ld/";
    nix-ld.inputs.nixpkgs.follows = "unstable";

    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    nix2sbom.url = "github:louib/nix2sbom";
    nix2sbom.inputs.nixpkgs.follows = "unstable";

    sbomnix = {
      url = "github:tiiuae/sbomnix/c0a07db80c1173c4f6a7957c5ea6ec416698fc3e";
      inputs.nixpkgs.follows = "unstable";
    };

    mlflow-works.url = "gitlab:usmcamp0811/dotfiles/38739f362e9c8e27880c0835f8db4a4866a61337";

    nix-snapshotter = {
      url = "github:yu-re-ka/nix-snapshotter/update";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    technofab = { url = "gitlab:TECHNOFAB/nix-packages"; };
    technofab.inputs.nixpkgs.follows = "nixpkgs";

    # GPG default configuration
    gpg-base-conf = {
      url = "github:drduh/config";
      flake = false;
    };

    campground-nvim = {
      url = "gitlab:usmcamp0811/campground-nvim";
      inputs.nixpkgs.follows = "unstable";
    };

    campground-packages.url = "gitlab:usmcamp0811/campground-packages";

    # Backup management
    poetry2nix = {
      url = "github:TyberiusPrime/poetry2nix/pyarrow_fix";
      inputs.nixpkgs.follows = "unstable";
    };

    # Run unpatched dynamically compiled binaries
    nix-ld-rs = {
      url = "github:nix-community/nix-ld-rs/8af5fc9add315c251edea8f659b56fc7836a163f";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dream2nix.url = "github:nix-community/dream2nix";
    scientific-fhs = {
      url = "github:usmcamp0811/scientific-fhs/pass-python-env-in";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-output-monitor.url = "github:maralorn/nix-output-monitor";
    nix-output-monitor.inputs.nixpkgs.follows = "nixpkgs";

    # dataflow2nix.url = "github:GTrunSec/dataflow2nix";

    compose2nix.url = "github:aksiksi/compose2nix";
    compose2nix.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "unstable";

    nix-ai.url = "github:nixified-ai/flake";
    nix-ai.inputs.nixpkgs.follows = "unstable";
    neorg-overlay = {
      url = "github:nvim-neorg/nixpkgs-neorg-overlay";
      inputs.nixpkgs.follows = "unstable";
    };

    crowdsec = {
      url = "git+https://codeberg.org/kampka/nix-flake-crowdsec.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    funkwhale.url = "github:usmcamp0811/funkwhale-flake";
    nixhelm.url = "github:nix-community/nixhelm";
    nixhelm.inputs.nixpkgs.follows = "unstable";
    # kubenix.url = "github:hall/kubenix";
    k0s-nix.url = "github:johbo/k0s-nix";
    kube-gen.url = "github:farcaller/nix-kube-generators";
    nixidy.url = "github:arnarg/nixidy";
    nix2container.url = "github:nlewo/nix2container";

    # yazi.url = "github:sxyazi/yazi/v25.5.31";
    bunny-yazi = {
      url = "github:stelcodes/bunny.yazi";
      flake = false;
    };

    official-plugins-yazi = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };

    mime-preview-yazi = {
      url = "github:DreamMaoMao/mime-preview.yazi";
      flake = false;
    };

    office-yazi = {
      url = "github:macydnah/office.yazi";
      flake = false;
    };

    eza-preview-yazi = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false;
    };

    hexyl-yazi = {
      url = "github:Reledia/hexyl.yazi";
      flake = false;
    };

    yaziline-yazi = {
      url = "github:llanosrocas/yaziline.yazi";
      flake = false;
    };

    githead-yazi = {
      url = "github:llanosrocas/githead.yazi";
      flake = false;
    };

    onedark-yazi = {
      url = "github:BennyOe/onedark.yazi";
      flake = false;
    };

    kanagawa-yazi = {
      url = "github:dangooddd/kanagawa.yazi";
      flake = false;
    };

    material-ocean-yazi = {
      url = "github:myamusashi/material-ocean.yazi";
      flake = false;
    };

    fzf-yazi = {
      url = "github:DreamMaoMao/fg.yazi";
      flake = false;
    };
    uv2nix.url = "github:pyproject-nix/uv2nix";
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
      };
    };
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
        # attic.overlays.default
        devshell.overlays.default
        nix-ld-rs.overlays.default
        nuenv.overlays.default
        nur.overlays.default
        nix-snapshotter.overlays.default
        poetry2nix.overlays.default
        nix-topology.overlays.default
        funkwhale.overlays.default
        # yazi.overlays.default
        k0s-nix.overlays.default
        crystal-forge.overlays.default
        # kubenix.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        nixtheplanet.nixosModules.macos-ventura
        home-manager.nixosModules.home-manager
        # nix-ld.nixosModules.nix-ld
        vault-service.nixosModules.nixos-vault-service
        # dataflow2nix.nixosModules.airflow
        nix-topology.nixosModules.default
        catppuccin.nixosModules.catppuccin
        flakeforge.nixosModules.flakeforge
        crowdsec.nixosModules.crowdsec
        funkwhale.nixosModules.default
        authentik-nix.nixosModules.default
        crystal-forge.nixosModules.crystal-forge
      ];

      # systemds.hosts.lucas.modules = with inputs; [
      #   unstable.nixosModules.services.k3s
      # ];
      systems.hosts.butler.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-p1
        nixos-hardware.nixosModules.lenovo-thinkpad-p53
      ];
      systems.hosts.gray.modules = with inputs; [ nixos-hardware.nixosModules.framework-16-7040-amd ];

      # Fixed bug in Amazon image builder: https://github.com/nix-community/nixos-generators/issues/150
      systems.hosts.base.modules = [ ({ ... }: { amazonImage.sizeMB = 32 * 1024; }) ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks =
        builtins.mapAttrs
          (_system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy)
          deploy-rs.lib;

      outputs-builder = channels: {
        # this needs to be `hooks` not `checks` because `checks` will get run with `deploy` and
        # which will break `deploy`.
        hooks.pre-commit-check = inputs.pre-commit-hooks.lib.${channels.nixpkgs.system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            # flake8.enable = true;
            # markdownlint.enable = true;
            # yamllint.enable = true;

            # deadnix.enable = true;
          };
        };
        nixidyEnvs = inputs.nixidy.lib.mkEnvs {
          pkgs = channels.nixpkgs;
          envs = { dev.modules = [ ./kubernetes/dev.nix ]; };
        };
      };
      terranixModule.modules = lib.findDefaultNixFiles ./modules/terraform;

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
        slidev = {
          path = ./templates/slidev;
          description = "A Template for making a flake with a devshell for running Slidev slides";
        };
        julia-project = {
          path = ./templates/julia-project;
          description = "An example of how to setup Julia Projects WIP";
        };
        simple-rust-package = {
          path = ./templates/simple-rust-package;
          description = "An Example of how to package a Rust app not in Snowfall but vanilla Nix";
        };
        python-package-with-tests = {
          path = ./templates/python-package-with-tests;
          description = "An Example of how to package Python with UV2Nix in vanilla Nix...also does checks and tests.";
        };
        basic-flake-system = {
          path = ./templates/basic-flake-system;
          description = "An Example of how to convert a vanilla NixOS system's configuration.nix to a flake.";
        };
      };
    };
}
