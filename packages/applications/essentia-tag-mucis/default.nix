{
  lib,
  pkgs,
  ...
}: let
  placeholderHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  versions = {
    "2026-02-17" = {
      rev = "main";
      srcHash = "sha256-lUWuyZnK+LcY4HKYcsaKJ12yEaxYZd3rOpcBuQyZQew=";

      essentiaTensorflow = {
        version = "2.1b6.dev1389";
        url = "https://files.pythonhosted.org/packages/f0/5f/7283634ee1d5d195d75986adc98a2309fab2df121a4618f3826eb2073d29/essentia_tensorflow-2.1b6.dev1389-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-ctLY10jpFt+TH6Vh8oTZpHrQ9Vc1Gs+9yVLUtBGMAbg=";
      };

      models = {
        "discogs-effnet-bs64-1.pb" = {
          url = "https://essentia.upf.edu/models/music-style-classification/discogs-effnet/discogs-effnet-bs64-1.pb";
          hash = "sha256-PtmvUNU2fAuceVspSwDnWZ5JQyRPTL03aGnzv8h3IbE=";
        };

        "genre_discogs400-discogs-effnet-1.pb" = {
          url = "https://essentia.upf.edu/models/classification-heads/genre_discogs400/genre_discogs400-discogs-effnet-1.pb";
          hash = "sha256-OIW6B4o1JJr5S45eQkdomvrEDeykQBpLyIja9aV5wBw=";
        };

        "genre_discogs400-discogs-effnet-1.json" = {
          url = "https://essentia.upf.edu/models/classification-heads/genre_discogs400/genre_discogs400-discogs-effnet-1.json";
          hash = "sha256-LTZzGdm3gv+hD2mr8OgFs6xOEImQJeW9us7aORmyQ+A=";
        };

        "mtg_jamendo_moodtheme-discogs-effnet-1.pb" = {
          url = "https://essentia.upf.edu/models/classification-heads/mtg_jamendo_moodtheme/mtg_jamendo_moodtheme-discogs-effnet-1.pb";
          hash = "sha256-A/KwRwIK7kqzn4iA2nva4qNtBqFQjWVsbUJK1NbeB6k=";
        };

        "mtg_jamendo_moodtheme-discogs-effnet-1.json" = {
          url = "https://essentia.upf.edu/models/classification-heads/mtg_jamendo_moodtheme/mtg_jamendo_moodtheme-discogs-effnet-1.json";
          hash = "sha256-1izZAmPk1hP6f8znqDHjOUUDlHlK9jaF+W4GXBqJarA=";
        };
      };
    };
  };

  defaultVersion = "2026-02-17";

  mkEssentiaToMetadata = version: let
    v = versions.${version};

    python = pkgs.python311;
    py = pkgs.python311Packages;

    essentia-tensorflow = py.buildPythonPackage rec {
      pname = "essentia-tensorflow";
      inherit (v.essentiaTensorflow) version;
      format = "wheel";

      src = pkgs.fetchurl {
        inherit (v.essentiaTensorflow) url hash;
      };

      nativeBuildInputs = with pkgs; [
        unzip
        autoPatchelfHook
      ];

      buildInputs = with pkgs; [
        stdenv.cc.cc
        zlib
        glib
        ffmpeg
        libsndfile
      ];

      propagatedBuildInputs = with py; [
        numpy
        six
      ];

      doCheck = false;
      pythonImportsCheck = [ ];
    };

    models = pkgs.stdenvNoCC.mkDerivation {
      pname = "essentia-to-metadata-models";
      inherit version;

      srcs = [
        (pkgs.fetchurl v.models."discogs-effnet-bs64-1.pb")
        (pkgs.fetchurl v.models."genre_discogs400-discogs-effnet-1.pb")
        (pkgs.fetchurl v.models."genre_discogs400-discogs-effnet-1.json")
        (pkgs.fetchurl v.models."mtg_jamendo_moodtheme-discogs-effnet-1.pb")
        (pkgs.fetchurl v.models."mtg_jamendo_moodtheme-discogs-effnet-1.json")
      ];

      unpackPhase = "true";

      installPhase = ''
        set -euo pipefail
        mkdir -p $out/share/essentia_models
        for f in $srcs; do
          cp -v "$f" $out/share/essentia_models/
        done
      '';
    };

    # ✅ Build a Python environment that includes runtime deps.
    pythonEnv = python.withPackages (ps: with ps; [
      numpy
      mutagen
      six
      essentia-tensorflow
    ]);
  in
    py.buildPythonApplication rec {
      pname = "essentia-to-metadata";
      inherit version;

      # Script repo (not setuptools/pyproject)
      format = "other";
      dontConfigure = true;
      dontBuild = true;

      # We wrap manually using pythonEnv; avoid wrap-python-hook/pythonPath issues.
      dontWrapPythonPrograms = true;

      src = pkgs.fetchFromGitHub {
        owner = "WB2024";
        repo = "Essentia-to-Metadata";
        rev = v.rev;
        hash = v.srcHash;
      };

      nativeBuildInputs = with pkgs; [
        makeWrapper
      ];

      installPhase = ''
        set -euo pipefail
        mkdir -p $out/libexec/essentia-to-metadata $out/bin
        cp -v tag_music.py $out/libexec/essentia-to-metadata/tag_music.py

        # ✅ Run the script with the interpreter from pythonEnv so numpy/mutagen/etc are available.
        makeWrapper ${pythonEnv}/bin/python $out/bin/essentia-to-metadata \
          --add-flags "$out/libexec/essentia-to-metadata/tag_music.py" \
          --add-flags "--model-dir ${models}/share/essentia_models"
      '';

      doCheck = false;

      meta = with lib; {
        description = "Intelligent audio analysis and automatic genre/mood tagging using Essentia ML models";
        homepage = "https://github.com/WB2024/Essentia-to-Metadata";
        license = licenses.mit;
        maintainers = [];
        platforms = platforms.linux;
      };
    };

  allVersions = lib.mapAttrs (version: _: mkEssentiaToMetadata version) versions;
  vPrefixedVersions =
    lib.mapAttrs'
      (version: drv: lib.nameValuePair "v${version}" drv)
      allVersions;

  defaultPackage = mkEssentiaToMetadata defaultVersion;
in
  defaultPackage // { passthru = allVersions // vPrefixedVersions; }
