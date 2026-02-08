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
final: prev: {
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
      nixhelm.chartsDerivations.${prev.system}
  );
  nixhelm = nixhelm;
  nixidy-cli = nixidy.packages.${prev.system}.default;
  nixidy-lib = nixidy.lib;

  # Crystal Forge slides
  cf-slides = crystal-forge.packages.${prev.system}.slides;
  cf-slides-campground = crystal-forge.packages.${prev.system}.slides.overrideAttrs (old: {
    postBuild =
      (old.postBuild or "")
      + ''
        echo "Rebuilding Slidev with custom base: /crystal-forge/"
        rm -rf dist
        slidev build --base "/crystal-forge/"
      '';
  });

  # Neovim
  campground-nvim = campground-nvim.packages.${prev.system}.nvim;
  neovim = campground-nvim.packages.${prev.system}.nvim;

  # macOS image builder
  makeDarwinImage = nixtheplanet.legacyPackages.${prev.system}.makeDarwinImage;

  # Neovide from old-nixpkgs
  neovide = old-nixpkgs.legacyPackages.${prev.system}.neovide;

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
  mkYarnPackage = old-nixpkgs.legacyPackages.${prev.system}.mkYarnPackage;

  # Comma for quick package running
  comma = comma.packages.${final.system}.comma;

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
    beets
    zathura
    clippy
    blueman
    djvulibre
    home-manager-path
    hyprcursor
    sway-unwrapped
    switch-to-configuration-ng
    vulnix
    ;

  # Jupyter environment builder
  inherit (jupyenv.lib.${final.system}) mkJupyterlabNew mkKernel;
}
