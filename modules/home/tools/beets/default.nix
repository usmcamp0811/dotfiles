{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;

let cfg = config.campground.tools.beets;

in {
  options.campground.tools.beets = with types; {
    enable = mkBoolOpt false "Whether or not to enable beets.";
    music-dir = mkOpt str "/export/media/music" "Directory for music files.";
  };

  config = mkIf cfg.enable {
    programs.beets = {
      enable = true;
      settings = {
        directory = cfg.music-dir;
        library = "~/.config/beets/library.db";
        ignore = [ ".jpg" ".jpeg" ".png" ".webp" ".gif" ".txt" ".pdf" ];
        ui = { color = true; };
        import = {
          move = true;
          write = true;
          autotag = true;
          log = "~/.config/beets/import.log";
          duplicate_action = "merge";
          incremental = true;
          singleton = true;
          timid = false;
          resume = true;
          quiet_fallback = "asis";
          group_albums = true;
          strong_rec_thresh = 0.4;
          default_action = "apply";
        };

        plugins = [
          "spotify"
          "info"
          "ftintitle"
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
            {
              name = "Never_Listened.m3u";
              query = "play_count: ";
            }
            {
              name = "Top_Rated.m3u";
              query = "rating:1";
            }
          ];
        };

        fetchart = {
          auto = true;
          sources = [ "coverart" "itunes" "amazon" "google" "albumart" ];
          minwidth = 500;
        };

        embedart = {
          auto = true;
          ifempty = true;
        };

        match = { strong_rec_thresh = 0.4; };

        replaygain = { auto = true; };

        scrub = { auto = true; };

        lastgenre = {
          auto = true;
          canonical = true;
          source = "track";
          whitelist = true;
          count = 3;
        };

        chroma = { auto = true; };

        # moods = {
        #   auto = true;
        #   source = "lastfm";
        #   write = true;
        # };
        #
        # styles = {
        #   auto = true;
        #   source = "musicbrainz";
        #   write = true;
        # };
      };
    };
  };
}
