{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  # csscade-theme = buildYarnTheme {
  #   pkgs = pkgs;
  #   pname = "slidev-theme-csscade";
  #   version = "0.1.0";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "usmcamp0811";
  #     repo = "slidev-theme-csscade";
  #     rev = "491da23c5c6928ee4f99881ff6fc2db130089c1f";
  #     hash = "sha256-koTSlTpYgPP+XH4AXe0CAbHJ9VIizcmMJmciATdXCHs=";
  #   };
  #   yarnNix = ./csscade-yarn-deps.nix;
  # };
  csscade-theme = buildNpmTheme {
    inherit pkgs;
    pname = "slidev-theme-csscade";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "Csscade";
      repo = "slidev-theme-csscade";
      rev = "2dfa4b7bd9863dac463d0b7efdbdc264a56f94ce";
      hash = "sha256-4xnuRLhHqNqtD5Yu9PZ/STRptCfz8m60chvGhmkt/SU=";
    };
    depsHash = "sha256-hpjXGy0KPOXxVS+Bo7o2p1d5lHRWU2/myRUN3ygHSz4=";
    meta.broken = true;
  };

  neversink-theme = buildPnpmTheme {
    inherit pkgs;
    pname = "slidev-theme-neversink";
    version = "0.3.6";
    src = pkgs.fetchFromGitHub {
      owner = "gureckis";
      repo = "slidev-theme-neversink";
      rev = "v0.3.6";
      hash = "sha256-JcdkZBcf059Pk5lqwGIlcTHmfIM54no98adeHe+TNBs=";
    };
    depsHash = "sha256-NKQ/MISoYnQFYMfcb8vOTE+YF1/AUHYRlGU4qNQalVY=";
    pnpm = pkgs.pnpm_9;
  };
  mokkapps-theme = buildPnpmTheme {
    inherit pkgs;
    pname = "slidev-theme-mokkapps";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "Mokkapps";
      repo = "slidev-theme-mokkapps";
      rev = "master";
      hash = "sha256-m2RXHI+vvszYaDxO38mLdxMKZbtUgAMrdSJBCINgQSc=";
    };
    depsHash = "sha256-ZJh47LQamNh1kPd8c/JTlkcQp9k2MwKLkIw+f+102DE=";
    pnpm = pkgs.pnpm_9;
  };
  eavise-theme = buildPnpmTheme {
    inherit pkgs;
    pname = "slidev-theme-eavise";
    version = "1.1.1-rc1";
    src = pkgs.fetchFromGitHub {
      owner = "0phoff";
      repo = "slidev-theme-eavise";
      rev = "v1.1.1-rc1";
      hash = "sha256-svILnvGD7SoECrhg6lSwDDWVcgxQONwCGw/nBYDpMOQ=";
    };
    depsHash = "sha256-7BWUjHR1BtVtOvYGVFYVia3vKiaWFKHiQTL+mI8qNDY=";
    pnpm = pkgs.pnpm_9;
  };
  dataroots-theme = buildYarnTheme {
    pkgs = pkgs;
    pname = "slidev-theme-dataroots";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "datarootsio";
      repo = "slidev-theme-dataroots";
      rev = "439c3add51c76c24953113380dded57fbdccc52b";
      hash = "sha256-9wU7+aBk8zVsRIaAkpr56ZSNLwiEBkLkJBAp1YY1iAU=";
    };
    yarnNix = ./dataroots-yarn-deps.nix;
  };
  custom-mokkapps-theme = pkgs.stdenv.mkDerivation {
    pname = "slidev-theme-mokkapps";
    version = "0.1.0";

    src = ./global-bottom.vue;

    nativeBuildInputs = [ pkgs.rsync pkgs.nodejs ]; # probably unnecessary, but safe

    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out
      rsync -a --exclude="global-bottom.vue" --chmod=+w ${mokkapps-theme}/ $out/
      rsync -a $src $out/global-bottom.vue
    '';
    meta = {
      description = "Mokkapps theme with custom global-bottom.vue";
      license = lib.licenses.mit;
    };
  };
  slidev-themes = buildPnpmTheme {
    inherit pkgs;
    pname = "slidev-themes";
    version = "0.22.0";
    src = pkgs.fetchFromGitHub {
      owner = "slidevjs";
      repo = "themes";
      rev = "v0.22.0";
      hash = "sha256-t6sg/nSbr2ytMHN1yuQy/kEDLyAYHXFVwcN1naeGhQc=";
    };
    depsHash = "sha256-7aY8Md7Je6SEAnkhzCpkRSOG5Q4A1wHqK34qMEG8HJo=";
    pnpm = pkgs.pnpm_8;
  };
in
slidev-themes
  // {
  inherit csscade-theme neversink-theme eavise-theme dataroots-theme;
  mokkapps-theme = custom-mokkapps-theme;
}
