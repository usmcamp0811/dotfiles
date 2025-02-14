{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.tools.beets;
  rawConfig = lib.generators.toYAML { } {
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
      timid = false;
      resume = true;
      quiet_fallback = "asis";
      group_albums = true;
      strong_rec_thresh = 0.4;
      default_action = "apply";
    };
    # paths = {
    #   default =
    #     "%asciify{$albumartist}/%asciify{$album}/%asciify{$track}_%asciify{$artist}-%asciify{$title}.mp3";
    #   singleton = "Singles/%asciify{$artist}-%asciify{$title}.mp3";
    #   comp =
    #     "Compilations/%asciify{$album}/%asciify{$track}_%asciify{$artist}-%asciify{$title}.mp3";
    # };
    # replace = {
    #   "[\\/]" = "_";
    #   "^\\." = "_";
    #   "[x00-x1f]" = "_";
    #   "[:]" = "_";
    #   "[*?\"<>|]" = "_";
    #   "\\s+$" = "";
    #   "\\s+" = "_";
    # };
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
    ];
    smartplaylist = {
      relative_to = "/export/media/music";
      playlist_dir = "/export/media/music";
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
          name = "Jazz_Night.m3u";
          query = [
            ''"genre::(Jazz|Smooth Jazz|Bebop|Swing)"''
            "year:1950..1980"
            "mood_acoustic:0.8.."
            "mood_melodic:0.7.."
            "mood_dark:..0.3"
          ];
        }

        {
          name = "Road_Trip_Rock.m3u";
          query = [
            ''"genre::(Classic Rock|Hard Rock|Blues Rock)"''
            "year:1965..1995"
            "mood_energetic:0.8.."
            "mood_melodic:0.5.."
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
          name = "Funky_Grooves.m3u";
          query = [
            ''"genre::(Funk|Soul|R&B|Disco)"''
            "year:1960..1990"
            "mood_energetic:0.7.."
            "mood_melodic:0.6.."
            "mood_acoustic:..0.5"
          ];
        }

        {
          name = "Darkwave_Moods.m3u";
          query = [
            ''"genre::(Darkwave|Gothic Rock|Industrial)"''
            "year:1980.."
            "mood_dark:0.7.."
            "mood_melodic:0.5.."
            "mood_energetic:..0.6"
          ];
        }
        {
          name = "Phil_Collins_Vibes.m3u";
          query = [
            ''"genre::(Pop|Soft Rock|Adult Contemporary|Synthpop)"''
            "year:1980..1999"
            "mood_melodic:0.8.."
            "mood_acoustic:..0.5"
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
      source = "artist";
    };
    chroma = { auto = true; };
  };

  formattedConfig =
    pkgs.runCommand "beets-config.yaml" { buildInputs = [ pkgs.yq ]; } ''
      echo '${rawConfig}' | ${pkgs.yq}/bin/yq --yaml-output > $out
    '';

in
{
  options.campground.tools.beets = with types; {
    enable = mkBoolOpt false "Whether or not to enable beets.";
    music-dir = mkOpt str "/export/media/music" "Place you got music";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ beets chromaprint yq ];

    home.file.".config/beets/config.yaml".text = rawConfig;
  };
}
