{ kube-gen
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

  mkYarnPackage = old-nixpkgs.legacyPackages.${prev.system}.mkYarnPackage;

  cargo-auditable = prev.cargo-auditable.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  });

  # python3Packages =
  #   prev.python3Packages
  #   // {
  #     pyrate-limiter = prev-nixpkgs.legacyPackages.${prev.system}.python3Packages.pyrate-limiter;
  #     requests-ratelimiter = requestsRatelimiterPkg prev.python3Packages;
  #     lap = lapPkg prev.python3Packages;
  #   };
  #
  # python312Packages =
  #   prev.python312Packages
  #   // {
  #     pyrate-limiter = prev-nixpkgs.legacyPackages.${prev.system}.python312Packages.pyrate-limiter;
  #     requests-ratelimiter = requestsRatelimiterPkg prev.python312Packages;
  #     lap = lapPkg prev.python312Packages;
  #   };
  #
  # python313Packages =
  #   prev.python313Packages
  #   // {
  #     pyrate-limiter = prev-nixpkgs.legacyPackages.${prev.system}.python313Packages.pyrate-limiter;
  #     requests-ratelimiter = requestsRatelimiterPkg prev.python313Packages;
  #     lap = lapPkg prev.python313Packages;
  #   };
}
  // {
  inherit (channels.unstable) zookeeper vaultwarden vault-bin vault lemmy-server lemmy-help pds pdsadmin rofi k3s pnpm_9 beets;
  inherit (channels.prev-nixpkgs) nginx yarn2nix yarn python313Packages python312Packages eza fetchCargoVendor swaynotificationcenter rustPlatform julia;
  inherit
    (prev-nixpkgs.legacyPackages.${prev.system})
    auditable-cargo
    auditable-cargo-bootstrap
    cargo
    rustfmt
    ;
}
