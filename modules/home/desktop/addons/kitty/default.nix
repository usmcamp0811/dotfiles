{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.desktop.addons.kitty;
in
{
  options.campground.desktop.addons.kitty = {
    enable = mkEnableOption "Kitty";
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;
    home.packages = [
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.sauce-code-pro
    ];
    programs.kitty = {
      enable = true;
      # themeFile = "Alabaster_Dark";
      # themeFile = "ayu_light";
      themeFile = "Seti";
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 11;
      };
      settings = {
        clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
        # Other useful settings for remote work
        allow_remote_control = "yes";
        listen_on = "unix:/tmp/mykitty";

        # Performance for remote connections
        sync_to_monitor = "no";

        # Fonts
        italic_font = "SourceCodePro";

        # Terminal bell
        enable_audio_bell = false;

        # Window layout
        inactive_text_alpha = "0.8";
        confirm_os_window_close = 0;

        # Color scheme
        background_opacity = "0.85";
      };
    };
  };
}
