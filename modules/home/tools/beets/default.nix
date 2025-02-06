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
    paths = {
      default =
        "%asciify{$albumartist}/%asciify{$album}/%asciify{$track}_%asciify{$artist}-%asciify{$title}.mp3";
      singleton = "Singles/%asciify{$artist}-%asciify{$title}.mp3";
      comp =
        "Compilations/%asciify{$album}/%asciify{$track}_%asciify{$artist}-%asciify{$title}.mp3";
    };
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
    ];
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
