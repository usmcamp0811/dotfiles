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
  mkYarnPackage = old-nixpkgs.legacyPackages.${prev.system}.mkYarnPackage;

  cargo-auditable = prev.cargo-auditable.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.python3Packages.requests ];
  });
  python312Packages =
    prev.python312Packages
    // {
      pyrate-limiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python312Packages.pyrate-limiter;
      requests-ratelimiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python312Packages.requests-ratelimiter;
      lap = final.python3Packages.buildPythonPackage rec {
        pname = "lap";
        version = "0.4.0";

        src = final.fetchPypi {
          inherit pname version;
          sha256 = "sha256-aQEpE09EOph9KnLbkgvi1SpM67PaqGL7If95hAj8Xl4=";
        };

        nativeBuildInputs = [ final.python3Packages.setuptools ];
        doCheck = false;

        meta = with final.lib; {
          description = "Linear assignment problem solver using LAPJV algorithm";
          homepage = "https://github.com/gatagat/lap";
          license = licenses.mit;
        };
      };
    };
  python313Packages =
    prev.python313Packages
    // {
      pyrate-limiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python313Packages.pyrate-limiter;
      requests-ratelimiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python313Packages.requests-ratelimiter;
      lap = final.python3Packages.buildPythonPackage rec {
        pname = "lap";
        version = "0.4.0";

        src = final.fetchPypi {
          inherit pname version;
          sha256 = "sha256-aQEpE09EOph9KnLbkgvi1SpM67PaqGL7If95hAj8Xl4=";
        };

        nativeBuildInputs = [ final.python3Packages.setuptools ];
        doCheck = false;

        meta = with final.lib; {
          description = "Linear assignment problem solver using LAPJV algorithm";
          homepage = "https://github.com/gatagat/lap";
          license = licenses.mit;
        };
      };
    };
  python3Packages =
    prev.python3Packages
    // {
      pyrate-limiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python3Packages.pyrate-limiter;
      requests-ratelimiter = prev-nixpkgs.outputs.legacyPackages.${prev.system}.python3Packages.requests-ratelimiter;
      lap = final.python3Packages.buildPythonPackage rec {
        pname = "lap";
        version = "0.4.0";

        src = final.fetchPypi {
          inherit pname version;
          sha256 = "sha256-aQEpE09EOph9KnLbkgvi1SpM67PaqGL7If95hAj8Xl4=";
        };

        nativeBuildInputs = [ final.python3Packages.setuptools ];
        doCheck = false;

        meta = with final.lib; {
          description = "Linear assignment problem solver using LAPJV algorithm";
          homepage = "https://github.com/gatagat/lap";
          license = licenses.mit;
        };
      };
    };
}
  // {
  inherit (channels.unstable) lemmy-server lemmy-help pds pdsadmin rofi k3s pnpm_9;
  inherit (channels.prev-nixpkgs) nginx yarn2nix yarn python313Packages python312Packages fetchCargoVendor swaynotificationcenter rustPlatform julia;
}
