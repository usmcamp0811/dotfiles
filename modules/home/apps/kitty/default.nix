{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.kitty;
in
{
  options.campground.apps.kitty = {
    enable = mkEnableOption "Kitty";
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;
    home.packages = [
      (pkgs.nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    ];
    programs.kitty = {
      enable = true;

      settings = {
        # Fonts
        font_family = "FiraCode Nerd Font Mono";
        italic_font = "SourceCodePro";
        font_size = 16;

        # Terminal bell
        enable_audio_bell = false;

        # Window layout
        inactive_text_alpha = 0.8;
        confirm_os_window_close = 0;

        # Color scheme
        background_opacity = 0.95;

        # Advanced
        allow_remote_control = "yes";
        listen_on = "/tmp/mykitty";

        # Include your theme file
        # include = "current-theme.conf";
      };
    };
  };
}
