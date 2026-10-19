{
  lib,
  pkgs,
  # Public "shared metadata cache" (Supabase) the tuner reads for TMDB/IMDb
  # enrichment (keywords, studios, ratings). Left empty, the placeholders stay in
  # the page and enrichment turns itself off, exactly like upstream's own
  # `docker build` without --build-arg. The anon key is public by design (row
  # level security protects the table) and ends up in the page either way.
  #
  # Override with: pkgs.fmf.nostalgex.override { supabaseUrl = "..."; supabaseAnonKey = "..."; }
  supabaseUrl ? "",
  supabaseAnonKey ? "",
  ...
}: let
  pname = "nostalgex";
  # Upstream tags the self-host web tuner as `tuner-v*` (the tvOS app uses `v*`).
  version = "1.0.2";

  src = pkgs.fetchFromGitHub {
    owner = "chadMueller";
    repo = "Nostalgex";
    rev = "tuner-v${version}";
    hash = "sha256-M2HMg+Zeub1QfsQ4i5g8xyJYbY7wy6uaAsLc9ehyXFM=";
  };
in
  pkgs.buildNpmPackage {
    inherit pname version src;

    # Upstream builds with node:22-alpine; vite 7 needs >= 22.12 anyway.
    nodejs = pkgs.nodejs_22;

    # Update this after running prefetch-npm-deps against upstream's package-lock.json
    npmDepsHash = "sha256-fYL+bALHjeQfAetOnrENYschZ6RPo8My/Q6SsvQPpVQ=";

    # `vite build --mode selfhost --outDir dist-selfhost`: just the two tuner pages
    # (web-tuner.html is also index.html) with hls.js, qrcodejs and every font
    # vendored from npm, analytics removed, and relative asset URLs. This is the
    # same output the upstream Docker image serves. The default `build` script
    # is the hosted marketing site and is not wanted here.
    npmBuildScript = "build:selfhost";

    env = {
      # Shown in the tuner and written to config.json.
      NOSTALGEX_TUNER_VERSION = version;
      VITE_SUPABASE_URL = supabaseUrl;
      VITE_SUPABASE_ANON_KEY = supabaseAnonKey;
    };

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/${pname}"
      cp -r dist-selfhost/. "$out/share/${pname}/"

      runHook postInstall
    '';

    # Lets fmf.services.nostalgex warn when enrichment is switched on for a
    # build that has no Supabase values to enrich with.
    passthru.enrichmentConfigured = supabaseUrl != "" && supabaseAnonKey != "";

    meta = with lib; {
      description = "Retro cable TV channel guide for a Plex, Jellyfin or Emby library (self-hosted web tuner)";
      longDescription = ''
        The static web tuner from nostalgex.app, built in upstream's self-host
        mode so it can be served over plain http next to a Jellyfin or Emby
        server (an https page cannot talk to a plain http media server).

        Only static files are installed, under share/nostalgex. Serve them with
        any static file server that serves .cjs as JavaScript, and provide
        /config.json (tunerVersion, musicLookups, enrichment) at runtime; the
        build ships a default one with enrichment enabled.
      '';
      homepage = "https://www.nostalgex.app/self-host";
      changelog = "https://github.com/chadMueller/Nostalgex/releases/tag/tuner-v${version}";
      # The MIT grant does not cover the Nostalgex name, icon or nostalgex.app site.
      license = licenses.mit;
      platforms = platforms.all;
    };
  }
