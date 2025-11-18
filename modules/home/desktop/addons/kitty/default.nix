{
  lib,
  config,
  pkgs,
  ...
}:
with campground; let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.campground.desktop.addons.kitty;
in {
  options.campground.desktop.addons.kitty = {
    enable = mkEnableOption "Kitty";
    themeFile = mkOpt lib.str "Modus_Vivendi" "Kitty Theme to use";
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;
    home.packages = [
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.sauce-code-pro
    ];

    programs.kitty = {
      enable = true;

      # Consider a calmer, high-legibility theme:
      themeFile = cfg.themeFile;
      # themeFile = "Modus_Operandi";  # light
      # themeFile = "Seti";

      font = {
        name = "FiraCode Nerd Font Mono";
        size = 12; # up from 11 for easier readability
      };

      settings = {
        clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

        # Useful for remote control
        allow_remote_control = "yes";
        listen_on = "unix:/tmp/mykitty";

        # Reduce flicker/tearing → less strain
        sync_to_monitor = "yes";

        # Fonts
        italic_font = "SourceCodePro";

        # Terminal bell
        enable_audio_bell = "no";

        # Cursor: blinking can be fatiguing
        cursor_blink_interval = "0";
        cursor_stop_blinking_after = "0";

        # Make inactive windows NOT dim (keeps consistent contrast)
        inactive_text_alpha = "1.0";

        # Kill transparency to avoid background visual noise
        background_opacity = "1.0";

        # Slightly more line height for legibility (pixels; tweak ±1–2)
        adjust_line_height = "2";

        # Don’t nag on close
        confirm_os_window_close = "0";
      };
    };
  };
}
