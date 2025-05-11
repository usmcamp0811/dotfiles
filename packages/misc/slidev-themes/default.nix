{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
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
  inherit neversink-theme mokkapps-theme csscade-theme;
}
