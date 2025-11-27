{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.jupyter;
in {
  options.campground.tools.jupyter = with types; {
    enable = mkBoolOpt false "Jupyter QtConsole";
    syntaxStyle =
      mkOpt str "gruvbox-dark" "Syntax style for Jupyter QtConsole.";
    fontSize = mkOpt int 14 "Font size for Jupyter QtConsole.";
  };

  config = mkIf cfg.enable {
    home.file.".config/jupyter/jupyter_qtconsole_config.py".text = ''
      c = get_config()  # noqa
      c.JupyterWidget.syntax_style = "${cfg.syntaxStyle}"  # specify color theme
      c.JupyterQtConsoleApp.hide_menubar = True
      c.ConsoleWidget.font_size = ${toString cfg.fontSize}
      c.ConsoleWidget.scrollbar_visibility = False
      c.JupyterConsoleApp.confirm_exit = False
      c.IPythonWidget.gui_completion = 'ncurses'
    '';

    home.packages = with pkgs; [
      python313Packages.ipython
      python313Packages.jupyter-console
      python313Packages.matplotlib-inline
      python313Packages.jupyter
      python313Packages.jupyter-core
      python313Packages.jupyter_server
      python313Packages.jupyterlab
      python313Packages.ipykernel
      python313Packages.qtconsole
      python313Packages.xcffib
      zlib
      gcc
      glib
      qt5.qtbase
      qt5.qtwebengine
    ];
  };
}
