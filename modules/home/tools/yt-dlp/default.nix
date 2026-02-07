{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.tools.yt-dlp;
in {
  options.fmf.tools.yt-dlp = with types; {
    enable = mkBoolOpt false "Whether or not to enable yt-dlp.";
  };

  config = mkIf cfg.enable {
    fmf.cli.aliases = {
      dl_music = ''
        ${pkgs.yt-dlp}/bin/yt-dlp -x --audio-format mp3 "$1" --write-thumbnail --add-metadata --embed-thumbnail --cookies-from-browser brave --output "%(playlist_title)s/%(playlist_index)02d_%(title)s.%(ext)s" --metadata-from-title "%(artist)s - %(title)s" --parse-metadata "playlist_title:%(album)s"'';
    };
    home.packages = with pkgs; [ yt-dlp ];
  };
}
