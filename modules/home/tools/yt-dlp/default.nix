{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.yt-dlp;
in {
  options.campground.tools.yt-dlp = with types; {
    enable = mkBoolOpt false "Whether or not to enable yt-dlp.";
  };

  config = mkIf cfg.enable {
    campground.cli.aliases = {
      dl_music = ''
        ${pkgs.yt-dlp}/bin/yt-dlp -x --audio-format mp3 $1 --write-thumbnail --add-metadata --embed-thumbnail --cookies-from-browser ${pkgs.brave}/bin/brave
      '';
    };
    home.packages = with pkgs; [ yt-dlp ];
  };
}
