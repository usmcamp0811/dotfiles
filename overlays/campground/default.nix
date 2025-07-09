{
  kube-gen,
  funkwhale,
  comma,
  process-compose-flake,
  prev-nixpkgs,
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
  lib,
  ...
}: final: prev:
{
  services-flake = import process-compose-flake.lib {pkgs = final;};
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

  nixidy-cli =
    nixidy.packages.${prev.system}.default;
  nixidy-lib =
    nixidy.lib;
  campground-nvim =
    campground-nvim.packages.${prev.system}.nvim;
  neovim =
    campground-nvim.packages.${prev.system}.nvim;
  makeDarwinImage =
    nixtheplanet.legacyPackages.${prev.system}.makeDarwinImage;
  nixhelm =
    nixhelm;
  neovide =
    old-nixpkgs.legacyPackages.${prev.system}.neovide;
  # yazi =
  #   yazi.packages.${prev.system}.yazi;
  wasm-bindgen-cli =
    unstable.legacyPackages.x86_64-linux.wasm-bindgen-cli_0_2_100;

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
  # cargo-auditable = prev.cargo-auditable.overrideAttrs (old: {
  #   nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  # });
  # fetch-cargo-vendor-util = prev.fetch-cargo-vendor-util.overrideAttrs (old: {
  #   buildInputs = (old.buildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  # });
  mkYarnPackage =
    old-nixpkgs.legacyPackages.${prev.system}.mkYarnPackage;
}
// {
  inherit (comma.packages.${final.system}) comma;
  # inherit (funkwhale.overlay);
  inherit
    (channels.unstable)
    deploy-rs
    zookeeper
    vaultwarden
    vault-bin
    vault
    yazi
    lemmy-server
    lemmy-help
    pds
    pdsadmin
    rofi
    k3s
    pnpm_9
    beets
    zathura
    clippy
    librsvg
    adwaita-icon-theme
    appstream
    blueman
    djvulibre
    gnome-themes-extra
    gst-plugins-bad
    home-manager-path
    hyprcursor
    imagemagick
    imlib2
    inkscape
    sway-unwrapped
    wrapGAppsHook
    switch-to-configuration-ng
    # xdg-desktop-portal
    ;
  inherit (channels.prev-nixpkgs) input-leap;
}
