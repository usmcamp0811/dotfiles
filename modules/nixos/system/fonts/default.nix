{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.fonts;
in
{
  options.campground.system.fonts = with types; {
    enable = mkBoolOpt false "Whether or not to manage fonts.";
    fonts = mkOpt (listOf package) [ ] "Custom font packages to install.";
  };

  config = mkIf cfg.enable {
    environment.variables = {
      # Enable icons in tooling since we have nerdfonts.
      LOG_ICONS = "true";
    };

    environment.systemPackages = with pkgs; [ font-manager ];
    # fonts.fonts = with pkgs;

    fonts.packages = with pkgs;
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-emoji
        hack-font
        font-awesome
        ibm-plex
        material-design-icons
        fira-mono
        dejavu_fonts
        fira-code-symbols
        (nerdfonts.override { fonts = [ "Hack" ]; })
      ] ++ cfg.fonts;
  };
}
