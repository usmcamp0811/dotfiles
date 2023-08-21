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
      (pkgs.nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" ]; })
    ];
    programs.kitty = {
      enable = true;
      theme = "Alabaster Dark";
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 17;
      };
      settings = {
        # Fonts
        italic_font = "SourceCodePro";

        # Terminal bell
        enable_audio_bell = false;

        # Window layout
        inactive_text_alpha = "0.8";
        confirm_os_window_close = 0;

        # Color scheme
        background_opacity = "0.85";

        # Advanced
        allow_remote_control = "yes";
        listen_on = "/tmp/mykitty";
      };
    };
  };
}
