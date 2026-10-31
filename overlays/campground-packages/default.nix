# Custom campground packages and integrations
# This contains packages specific to your campground setup that don't fit other categories
{
  kube-gen,
  jupyenv,
  funkwhale,
  comma,
  process-compose-flake,
  campground-nvim,
  nixhelm,
  nixtheplanet,
  old-nixpkgs,
  nixpkgs,
  channels,
  unstable,
  nixidy,
  uv2nix,
  npmlock2nix,
  crystal-forge,
  lib,
  ...
}:
final: prev: let
  system = prev.stdenv.hostPlatform.system;
in {
  # Services framework
  services-flake = import process-compose-flake.lib {pkgs = final;};

  # Kubernetes & Helm tools
  nixhelmCharts = lib.fix (
    self:
      lib.mapAttrs
      (
        repo: charts:
          lib.mapAttrs (_chart: drv: drv)
          charts
      )
      nixhelm.chartsDerivations.${system}
  );
  nixhelm = nixhelm;
  nixidy-cli = nixidy.packages.${system}.default;
  nixidy-lib = nixidy.lib;

  # Crystal Forge slides
  cf-slides = crystal-forge.packages.${system}.slides;
  cf-slides-campground = crystal-forge.packages.${system}.slides.overrideAttrs (old: {
    postBuild =
      (old.postBuild or "")
      + ''
        echo "Rebuilding Slidev with custom base: /crystal-forge/"
        rm -rf dist
        slidev build --base "/crystal-forge/"
      '';
  });

  # Neovim
  campground-nvim = campground-nvim.packages.${system}.nvim;
  neovim = campground-nvim.packages.${system}.nvim;

  # macOS image builder
  makeDarwinImage = nixtheplanet.legacyPackages.${system}.makeDarwinImage;

  # Neovide from old-nixpkgs
  neovide = old-nixpkgs.legacyPackages.${system}.neovide;

  # WASM tools
  wasm-bindgen-cli = unstable.legacyPackages.x86_64-linux.wasm-bindgen-cli_0_2_100;

  # Matomo with OIDC plugin
  matomo_5 = prev.matomo_5.overrideAttrs (old: rec {
    loginOIDCPlugin = prev.fetchFromGitHub {
      owner = "dominik-th";
      repo = "matomo-plugin-LoginOIDC";
      rev = "5.0.0";
      sha256 = "sha256-L1ET2EoO6lm648Xf6UcpT1NR5DU4yBhlzaQyrECFjzQ=";
    };

    installPhase =
      old.installPhase
      + ''
        echo "Including LoginOIDC plugin in Matomo package..."
        cp -r ${loginOIDCPlugin} $out/share/plugins/LoginOIDC
      '';
  });

  # Yarn packaging from old nixpkgs
  mkYarnPackage = old-nixpkgs.legacyPackages.${system}.mkYarnPackage;
  yarn2nix-moretea = old-nixpkgs.legacyPackages.${system}.yarn2nix-moretea;

  # Comma for quick package running
  comma = comma.packages.${system}.comma;

  # Packages from old-nixpkgs
  inherit (channels.old-nixpkgs) ckb-next postgresql16Packages postgresql14Packages;

  # Server packages from unstable (non-GUI, won't trigger Firefox/Electron rebuilds)
  inherit
    (channels.unstable)
    deploy-rs
    zookeeper
    vaultwarden
    vault-bin
    vault
    lemmy-server
    lemmy-help
    pds
    pdsadmin
    k3s
    pnpm_9
    zathura
    clippy
    blueman
    djvulibre
    home-manager-path
    sway-unwrapped
    switch-to-configuration-ng
    vulnix
    ;

  # beets comes from unstable, so it uses unstable's python set, where
  # pyrate-limiter 4.5.0 is built from source (not in any binary cache). nixpkgs
  # already skips test_limiter_01 as "timing-sensitive, fails under load", but not
  # these two siblings in the same file, and they fail on a busy farm builder with
  # `AssertionError` at tests/helpers.py:80. One failed test fails pyrate-limiter,
  # then requests-ratelimiter, beets, home-manager-path and the whole system.
  # Same cause and same fix as nixpkgs' existing entry; drop this once nixpkgs
  # disables them itself. Scoped to beets' python set so nothing else rebuilds.
  beets = let
    unstablePython = channels.unstable.python3.override (old: {
      packageOverrides =
        channels.unstable.lib.composeExtensions
        (old.packageOverrides or (_: _: {}))
        (_: pyPrev: {
          pyrate-limiter = pyPrev.pyrate-limiter.overridePythonAttrs (prevAttrs: {
            disabledTests =
              (prevAttrs.disabledTests or [])
              ++ [
                "test_limiter_async_factory_get"
                "test_limiter_async_factory_get_weight0"
              ];
          });
        });
      self = unstablePython;
    });
  in
    channels.unstable.beets.override {python3 = unstablePython;};

  # cadwyn's pyproject sets pytest `filterwarnings = error`, and anyio 4.15
  # deprecated `anyio.abc.BlockingPortal`, which starlette's TestClient still
  # touches. The DeprecationWarning becomes an ImportError in conftest.py, so
  # cadwyn fails, taking apache-airflow-core and every Airflow VM with it.
  # `-W` on the command line takes precedence over the ini filter (tests only;
  # the installed package is unchanged). Done via
  # pythonPackagesExtensions because nixpkgs' apache-airflow builds its own
  # `python3.override { packageOverrides = ...; }` set, which would discard a
  # packageOverrides passed in from outside. Drop once starlette/cadwyn catch up.
  pythonPackagesExtensions =
    prev.pythonPackagesExtensions
    ++ [
      (_: pyPrev: {
        cadwyn = pyPrev.cadwyn.overridePythonAttrs (old: {
          pytestFlags =
            (old.pytestFlags or [])
            # No spaces allowed: pytestFlags is word-split without structuredAttrs.
            ++ ["-Wignore::DeprecationWarning"];
        });
      })
    ];

  # Jupyter environment builder
  inherit (jupyenv.lib.${system}) mkJupyterlabNew mkKernel;
}
