{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.libreoffice;
in {
  options.fmf.apps.libreoffice = with types; {
    enable = mkBoolOpt false "Whether or not to enable libreoffice.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Use the GTK build instead of libreoffice-qt: the Qt build pulls in
      # libreoffice-kde-dependencies -> KDE6 frameworks -> pyside6, which
      # fails to compile on nixpkgs 26.05. The GTK build has no pyside6
      # dependency and is functionally equivalent for our use.
      libreoffice
      hunspell
      hunspellDicts.uk_UA
      hunspellDicts.th_TH
    ];
  };
}
