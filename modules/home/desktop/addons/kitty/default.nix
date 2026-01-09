{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.fmf.desktop.addons.kitty;

  # Pre-defined custom themes
  customThemes = {
    ayu = ./themes/ayu.conf;
    # Add more themes here as needed
  };
in {
  options.fmf.desktop.addons.kitty = {
    enable = mkEnableOption "Kitty";

    themeFile = mkOpt types.str "Modus_Vivendi" "Built-in Kitty theme name to use (ignored if customTheme is set)";

    customTheme = mkOpt (types.nullOr types.path) null ''
      Path to a custom theme file (overrides themeFile).
      You can reference pre-defined themes via the 'themes' option below,
      or provide your own path/derivation.
    '';

    themes = mkOpt (types.attrsOf types.path) customThemes "Pre-defined custom themes (read-only)";

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

      # Disable paste confirmation
      paste_actions = "confirm-if-large";

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

        # Use built-in themeFile only if no custom theme is set
        # mkDefault allows Stylix to override this
        themeFile = mkIf (cfg.customTheme == null) (mkDefault cfg.themeFile);
        # themeFile = "Modus_Operandi";  # light
        # themeFile = "Seti";

        # Font now comes from the option (with your defaults)
        # mkDefault allows Stylix to override this
        font = mkDefault cfg.font;

        # Settings now come from the option (with your defaults)
        # mkDefault allows Stylix to override this
        settings = mkDefault cfg.settings;

        # Include custom theme if provided, plus apply settings via extraConfig
        # extraConfig settings won't be overridden by Stylix
        extraConfig = ''
          ${optionalString (cfg.customTheme != null) (builtins.readFile cfg.customTheme)}

          # Settings that shouldn't be overridden by Stylix
          clipboard_control ${cfg.settings.clipboard_control or "write-clipboard write-primary read-clipboard read-primary"}
          paste_actions ${cfg.settings.paste_actions or "confirm-if-large"}
          allow_remote_control ${cfg.settings.allow_remote_control or "yes"}
          listen_on ${cfg.settings.listen_on or "unix:/tmp/mykitty"}
          sync_to_monitor ${cfg.settings.sync_to_monitor or "yes"}
          italic_font ${cfg.settings.italic_font or "auto"}
          enable_audio_bell ${cfg.settings.enable_audio_bell or "no"}
          cursor_blink_interval ${cfg.settings.cursor_blink_interval or "0"}
          cursor_stop_blinking_after ${cfg.settings.cursor_stop_blinking_after or "0"}
          inactive_text_alpha ${cfg.settings.inactive_text_alpha or "1.0"}
          adjust_line_height ${cfg.settings.adjust_line_height or "2"}
          confirm_os_window_close ${cfg.settings.confirm_os_window_close or "0"}
        '';
      }
      // cfg.extraOptions;
  };
}
