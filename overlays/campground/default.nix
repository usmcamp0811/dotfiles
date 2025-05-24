{ kube-gen
, funkwhale
, comma
, prev-nixpkgs
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
let
  lapPkg = pythonPackages:
    pythonPackages.buildPythonPackage rec {
      pname = "lap";
      version = "0.4.0";

      src = final.fetchPypi {
        inherit pname version;
        sha256 = "sha256-aQEpE09EOph9KnLbkgvi1SpM67PaqGL7If95hAj8Xl4=";
      };

      nativeBuildInputs = [ pythonPackages.setuptools ];
      doCheck = false;

      meta = with final.lib; {
        description = "Linear assignment problem solver using LAPJV algorithm";
        homepage = "https://github.com/gatagat/lap";
        license = licenses.mit;
      };
    };

  requestsRatelimiterPkg = pythonPackages:
    pythonPackages.buildPythonPackage rec {
      pname = "requests-ratelimiter";
      version = "0.4.0";

      src = final.fetchPypi {
        inherit pname version;
        sha256 = "sha256-HypwHqLzYp97x7zKnqSejAV0zQq3fTrW4ldn4NdQ16A=";
      };

      propagatedBuildInputs = [ pythonPackages.requests ];
      nativeBuildInputs = [ pythonPackages.setuptools ];
      doCheck = false;

      meta = with final.lib; {
        description = "Rate limiter for python-requests";
        homepage = "https://github.com/itsayellow/requests-ratelimiter";
        license = licenses.mit;
      };
    };
in
{
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
  wasm-bindgen-cli = unstable.legacyPackages.x86_64-linux.wasm-bindgen-cli_0_2_100;

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
  cargo-auditable = prev.cargo-auditable.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  });
  fetch-cargo-vendor-util = prev.fetch-cargo-vendor-util.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  });

  mkYarnPackage = old-nixpkgs.legacyPackages.${prev.system}.mkYarnPackage;
}
  // {
  inherit (comma.packages.${final.system}) comma;
  inherit (funkwhale.overlay);
  inherit (channels.unstable) deploy-rs zookeeper vaultwarden vault-bin vault lemmy-server lemmy-help pds pdsadmin rofi k3s pnpm_9 beets;
  inherit
    (channels.prev-nixpkgs)
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
    xdg-desktop-portal
    ;
}
