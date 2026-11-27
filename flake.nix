{
  description = "Campground Config";

  # Inputs are pinned by tack (https://github.com/manic-systems/tack), not by flake inputs.
  # Edit .tack/pins.toml (or use `tack add/rm/update`); the lock lives in .tack/pins.lock.json.
  outputs = {self, ...} @ args: let
    pins = (import ./.tack) {overrides = args.tackOverrides or {};};
    # Drop tack's reserved attrs: snowfall/flake-utils-plus treat every attr of `inputs` as an input
    # (e.g. nix.linkInputs symlinks each one into /etc/nix/inputs).
    # tack returns a `type = "fetch"` pin (flake = false) as a bare store path string; flakes give an
    # attrset with outPath/rev/narHash. Restore that shape (flake-utils-plus reads `value.outPath`).
    asInput = name: value:
      if builtins.isString value
      then
        {outPath = value;}
        // builtins.intersectAttrs {rev = 0; narHash = 0; lastModified = 0;} (pins._meta.${name} or {})
      else value;
    tackInputs = builtins.mapAttrs asInput (removeAttrs pins ["_meta" "_patched" "__functor"]);
    inputs = tackInputs // {inherit self;};
    inherit (inputs) deploy-rs;

    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;
      snowfall = {
        meta = {
          name = "fmf";
          title = "AI Campground";
        };

        namespace = "fmf";
      };
    };
  in
    lib.mkFlake {
      # nixpkgs 26.11 dropped x86_64-darwin; flake-utils-plus defaults to including it
      supportedSystems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.6"
          "python-2.7.18.7"
          "qtwebkit-5.212.0-alpha4"
          "python3.11-apache-airflow-2.7.3"
          "mbedtls-2.28.10"
        ];
      };

      overlays = with inputs; [
        # Must stay first. snowfall-lib (upstream master too) builds the overlays it generates, including
        # the `package/*` ones below, with `channel-systems.${prev.system}`, and nixpkgs warns that
        # `pkgs.system` is renamed to `stdenv.hostPlatform.system`. Defining `system` here makes the later
        # overlays' `prev.system` a plain string. Drop once snowfall-lib stops using `prev.system`.
        (final: prev: {system = prev.stdenv.hostPlatform.system;})
        # Must come first - provides nix-unstable for packages
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
        flakeforge.overlay
        # yazi.overlays.default
        k0s-nix.overlays.default
        crystal-forge.overlays.default
        mcp-nixos.overlays.default
        # kubenix.overlays.default
      ];

      systems.modules.nixos = with inputs;
        [
          nixtheplanet.nixosModules.macos-ventura
          home-manager.nixosModules.home-manager
          # nix-ld.nixosModules.nix-ld
          vault-service.nixosModules.nixos-vault-service
          # dataflow2nix.nixosModules.airflow
          nix-topology.nixosModules.default
          # catppuccin.nixosModules.catppuccin
          stylix.nixosModules.stylix
          flakeforge.nixosModules.flakeforge
          funkwhale.nixosModules.default
          authentik-nix.nixosModules.default
          crystal-forge.nixosModules.crystal-forge
          nixos-router.nixosModules.default
          impermanence.nixosModules.impermanence
          microvm.nixosModules.host
          nixos-boot.nixosModules.default
          nix-grpc-store.nixosModules.default
        ]
        ++ (lib.attrValues (
          lib.filterAttrs (name: _: lib.hasPrefix "stig" name) crystal-forge.nixosModules
        ))
        # The fleet's network zones (shared by every host) and what a hypervisor reads from the committed
        # output of `fleet` (see docs/HOST-MODEL.md and network/)
        ++ [
          ./network/zones.nix
          ./network/microvm-host.nix
        ];

      # systemds.hosts.lucas.modules = with inputs; [
      #   unstable.nixosModules.services.k3s
      # ];

      systems.hosts = let
        hostDir = ./systems/x86_64-linux;
        hostNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir hostDir));
        # Per-host extra modules
        extra = with inputs; {
          blue-ridge = [disko.nixosModules.disko];
          butler = [
            nixos-hardware.nixosModules.lenovo-thinkpad-p1
            nixos-hardware.nixosModules.lenovo-thinkpad-p53
          ];
          gray = [nixos-hardware.nixosModules.framework-16-7040-amd];
        };
        # A host's fmf.host record: host.nix (identity, interfaces, placement), storage.nix (a MicroVM's
        # shares and store layout) and attachment.nix (network attachment). See docs/HOST-MODEL.md.
        record = name:
          builtins.filter builtins.pathExists [
            (hostDir + "/${name}/host.nix")
            (hostDir + "/${name}/storage.nix")
            (hostDir + "/${name}/attachment.nix")
          ];
      in
        lib.genAttrs hostNames (name: {
          modules =
            lib.optional (lib.hasPrefix "vm-" name) inputs.microvm.nixosModules.microvm
            ++ (extra.${name} or [])
            ++ record name;
        })
        // {
          base.modules = [({...}: {amazonImage.sizeMB = 32 * 1024;})];
        };

      # Fixed bug in Amazon image builder: https://github.com/nix-community/nixos-generators/issues/150

      deploy = lib.mkDeploy {inherit (inputs) self;};

      # fmf's pinned inputs for downstream flakes. With tack there are no flake inputs, so
      # `fmf.inputs` is empty; Campground reads `fmf.pins.<name>` (microvm, stylix, crystal-forge, ...).
      pins = tackInputs;

      # nixpkgs 26.11 dropped x86_64-darwin, so don't build deploy checks for it
      checks =
        builtins.mapAttrs (
          _system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy
        )
        (builtins.removeAttrs deploy-rs.lib ["x86_64-darwin"]);

      outputs-builder = channels: {
        # this needs to be `hooks` not `checks` because `checks` will get run with `deploy` and
        # which will break `deploy`.
        hooks.pre-commit-check =
          inputs.pre-commit-hooks.lib.${channels.nixpkgs.stdenv.hostPlatform.system}.run
          {
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
          envs = {
            dev.modules = [./kubernetes/dev.nix];
          };
        };

        # # Router security checks
        # checks = {
        #   router-security = import ./checks/router-security.nix {
        #     pkgs = channels.nixpkgs;
        #     lib = channels.nixpkgs.lib;
        #     system = channels.nixpkgs.system;
        #   };
        # };
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
        snowfall = {
          path = ./templates/snowfall;
          description = "A template to quickly create a Snowfall based flake for managing systems; has some modules in it for examples...";
        };
        example-downstream-flake = {
          path = ./templates/example-downstream-flake;
          description = "A template to demonstrate and point to how to use this flake as an upstream source for NixOS Modules";
        };
      };
    };
}
