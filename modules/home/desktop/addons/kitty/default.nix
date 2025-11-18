{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.campground.desktop.addons.kitty;
in {
  options.campground.desktop.addons.kitty = {
    enable = mkEnableOption "Kitty";

    themeFile = mkOpt types.str "Modus_Vivendi" "Kitty theme to use";

    # Free-form font options, defaulting to your current font block.
    # This is assigned to programs.kitty.font.
    font = mkOpt (types.attrsOf types.anything) {
      name = "FiraCode Nerd Font Mono";
      size = 12; # up from 11 for easier readability
    } "Font configuration passed to programs.kitty.font.";

    # All kitty.conf-style settings. These default to what you had before,
    # and are passed straight to programs.kitty.settings.
    settings = mkOpt (types.attrsOf types.str) {
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
    } "Attrset of kitty settings (merged into programs.kitty.settings).";

    # Free-form extra options passed directly to programs.kitty,
    # e.g. keybindings, extraConfig, mappings, etc.
    extraOptions = mkOpt (types.attrsOf types.anything) {} ''
      Extra options merged into programs.kitty. Use this to set any
      kitty/home-manager option not explicitly exposed above.
    '';
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;

    home.packages = [
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.sauce-code-pro
    ];

    programs.kitty =
      {
        enable = true;

        # Theme (still controlled by cfg.themeFile)
        themeFile = cfg.themeFile;
        # themeFile = "Modus_Operandi";  # light
        # themeFile = "Seti";

        # Font now comes from the option (with your defaults)
        font = cfg.font;

        # Settings now come from the option (with your defaults)
        settings = cfg.settings;
      }
      // cfg.extraOptions;
  };
}
