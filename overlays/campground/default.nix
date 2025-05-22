{ kube-gen
, campground-nvim
, nixhelm
, nixtheplanet
, old-nixpkgs
, nixpkgs
, channels
, unstable
, nixidy
, uv2nix
, yazi
, npmlock2nix
, lib
, ...
}: final: prev:
{
  # existing entries ...
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

  nixidy-cli = nixidy.packages.${prev.system}.default;
  nixidy-lib = nixidy.lib;
  campground-nvim = campground-nvim.packages.${prev.system}.nvim;
  neovim = campground-nvim.packages.${prev.system}.nvim;
  makeDarwinImage = nixtheplanet.legacyPackages.${prev.system}.makeDarwinImage;
  nixhelm = nixhelm;
  neovide = old-nixpkgs.legacyPackages.${prev.system}.neovide;
  yazi = yazi.packages.${prev.system}.yazi;
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
}
  // {
  inherit (channels.unstable) lemmy-server lemmy-help pds pdsadmin k3s pnpm_9 python312Packages python3Packages;
  inherit (channels.prev-nixpkgs) fetchCargoVendor cargo-auditable rustPlatform;
}
