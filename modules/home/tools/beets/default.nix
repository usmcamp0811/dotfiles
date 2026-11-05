{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.beets;
in {
  options.fmf.tools.beets = with types; {
    enable = mkBoolOpt false "Whether or not to enable beets.";
    music-dir = mkOpt str "/export/media/music" "Directory for music files.";
    acoustid-apikey-file = mkOpt (types.nullOr types.str) null ''
      Path to a file (e.g. rendered by vault-agent at activation time)
      containing the AcoustID API key, used by the chroma plugin for audio
      fingerprint matching. Not read at build time - the file's contents are
      merged into ~/.config/beets/config.yaml by a home-manager activation
      script, so the key never lands in the Nix store (programs.beets writes
      that file as a symlink into the store, which would otherwise make any
      secret in `settings` permanently world-readable there). Get a free key
      at https://acoustid.org/api-key.
    '';
  };

  config = mkIf cfg.enable {
    programs.beets = {
      enable = true;
      settings = {
        directory = cfg.music-dir;
        library = "~/.config/beets/library.db";

        ignore = ["*.jpg" "*.jpeg" "*.png" "*.webp" "*.gif" "*.txt" "*.pdf"];
        clutter = ["Thumbs.db" ".DS_Store" "desktop.ini" "AlbumArt*"];
        ignore_hidden = true;

        ui = {color = true;};

        import = {
          move = false;
          copy = false;
          link = false;
          hardlink = false;
          write = true;
          autotag = true;
          log = "~/.config/beets/import.log";
          duplicate_action = "merge";
          incremental = true;
          singleton = false; # album-aware
          group_albums = true;
          timid = false;
          resume = true;
          quiet_fallback = "asis";
          default_action = "apply";
        };

        match = {
          strong_rec_thresh = 0.7;
          preferred = {
            countries = ["US" "CA"];
            media = ["CD" "Digital Media"];
            original_year = true;
          };
        };

        plugins = [
          "info"
          "edit"
          "fetchart"
          "embedart"
          "scrub"
          "replaygain"
          "lastgenre"
          "chroma"
          "duplicates"
          "smartplaylist"
          "mbsync"
        ];

        smartplaylist = {
          relative_to = cfg.music-dir;
          playlist_dir = cfg.music-dir;
          playlists = [
            {
              name = "Never_Listened.m3u";
              query = "play_count: ";
            }
            {
              name = "Top_Rated.m3u";
              query = "rating:1";
            }
            {
              name = "80s_New_Wave.m3u";
              query = [
                ''"genre::(New Wave|Synthpop|Post-Punk)"''
                "year:1978..1992"
                "mood_energetic:0.7.."
                "mood_dark:..0.4"
              ];
            }
            {
              name = "Chillwave_Beats.m3u";
              query = [
                ''"genre::(Chillwave|Lo-Fi|Downtempo|Ambient)"''
                "year:2000.."
                "mood_melodic:0.7.."
                "mood_acoustic:..0.4"
                "mood_energetic:..0.6"
              ];
            }
          ];
        };

        fetchart = {
          auto = true;
          sources = ["coverart" "itunes" "amazon" "google" "albumart"];
          minwidth = 500;
        };
        embedart = {
          auto = true;
          ifempty = true;
        };
        replaygain = {auto = true;};
        scrub = {auto = true;};

        lastgenre = {
          auto = true;
          canonical = true;
          source = "track";
          whitelist = true;
          count = 3;
        };
        chroma = {auto = true;};
      };
    };

    # Merge the AcoustID key into the generated config.yaml after
    # home-manager (re)creates its symlink into the store, every activation -
    # so it always reflects both the latest declarative settings and the
    # latest key, without the key ever being written to the store itself.
    home.activation.beetsAcoustidApikey = mkIf (cfg.acoustid-apikey-file != null) (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        configFile="$HOME/.config/beets/config.yaml"
        keyFile="${cfg.acoustid-apikey-file}"
        if [ -s "$keyFile" ]; then
          baseConfig=$(readlink -f "$configFile")
          cat "$baseConfig" > "$configFile.tmp"
          printf 'acoustid_apikey: %s\n' "$(cat "$keyFile")" >> "$configFile.tmp"
          mv "$configFile.tmp" "$configFile"
        else
          echo "Warning: beets acoustid-apikey-file '$keyFile' is missing or empty; chroma plugin will have no AcoustID key." >&2
        fi
      ''
    );
  };
}
