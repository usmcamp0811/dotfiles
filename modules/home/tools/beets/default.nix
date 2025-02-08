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
      playlist_dir = "/export/media/music/playlists";
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
          name = "Popular_Chill.m3u";
          query = [ ''"genre::(Ambient|Chillout)" play_count:5..'' ];
        }
        {
          name = "UnPlayed_Chill.m3u";
          query = [ ''"genre::(Ambient|Chillout)" play_count: '' ];
        }
        {
          name = "Popular_DrumBass.m3u";
          query = [ ''genre:"Drum & Bass" play_count:5..'' ];
        }
        {
          name = "UnPlayed_DrumBass.m3u";
          query = [ ''genre:"Drum & Bass" play_count: '' ];
        }
        {
          name = "Popular_ProgHouseTrance.m3u";
          query = [ ''"genre::(Progressive House|Trance)" play_count:12..'' ];
        }
        {
          name = "UnPlayed_ProgHouseTrance.m3u";
          query = [ ''"genre::(Progressive House|Trance)" play_count:..0'' ];
        }
        {
          name = "UnPlayedAAgressive.m3u";
          query = [ "mood_aggressive:0.90.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedHappy.m3u";
          query = [ "mood_happy:0.95.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedReallyHappy.m3u";
          query = [ "mood_happy:0.99.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedSad.m3u";
          query = [ "mood_sad:0.95.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedParty.m3u";
          query = [ "mood_party:0.95.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedReallyParty.m3u";
          query = [ "mood_party:0.99.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedRelaxed.m3u";
          query = [ "mood_relaxed:0.95.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedDanceable.m3u";
          query = [ "danceable:0.95.. play_count:..0 ^genre:Christmas" ];
        }
        {
          name = "UnPlayedHarmonicA.m3u";
          query =
            [ ''"chords_key::(A|D|E|F#)" play_count:..0 ^genre:Christmas'' ];
        }
        {
          name = "UnPlayedHarmonicF.m3u";
          query =
            [ ''"chords_key::(F|C|Bb|D)" play_count:..0 ^genre:Christmas'' ];
        }
        {
          name = "TopRatedNotPlayedRecently.m3u";
          query = [ "rating:0.8.. last_played:..-6m ^genre:Christmas" ];
        }
        {
          name = "UnPlayedAcousticLady.m3u";
          query = [
            ''
              gender:"female" mood_acoustic:0.95.. play_count:..0 ^genre:Christmas''
          ];
        }
        {
          name = "UnPlayedAcousticGuy.m3u";
          query = [
            ''
              gender:"male" ^gender:"fe" mood_acoustic:0.95.. play_count:..0 ^genre:Christmas''
          ];
        }
        {
          name = "UnPlayedElectronicLady.m3u";
          query = [
            ''
              gender:"female" mood_electronic:0.95.. play_count:..0 ^genre:Christmas''
          ];
        }
        {
          name = "UnPlayedElectronicGuy.m3u";
          query = [
            ''
              gender:"male" ^gender:"fe" mood_electronic:0.95.. play_count:..0 ^genre:Christmas''
          ];
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
