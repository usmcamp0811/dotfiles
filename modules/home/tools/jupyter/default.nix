{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.jupyter;
in
{
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
      python311Packages.ipython
      python311Packages.jupyter_console
      python311Packages.matplotlib-inline
      python311Packages.jupyter
      python311Packages.jupyter-core
      python311Packages.jupyter_server
      python311Packages.jupyterlab
      python311Packages.ipykernel
      python311Packages.qtconsole
      python311Packages.xcffib
      # libstdcxx5
      zlib
      gcc
      glib
      qt5.qtbase
      qt5.qtwebengine
    ];
  };
}
