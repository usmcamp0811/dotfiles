{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.jupyter;
in
{
  options.campground.tools.jupyter = with types; {
    enable = mkBoolOpt false "Jupyter QtConsole";
    syntaxStyle = mkOpt str "gruvbox-dark" "Syntax style for Jupyter QtConsole.";
    fontSize = mkOpt int 14 "Font size for Jupyter QtConsole.";
  };

  config = mkIf cfg.enable {

    home.file.".jupyter/jupyter_qtconsole_config.py".text = ''
      c = get_config()  # noqa
      c.JupyterWidget.syntax_style = "${cfg.syntaxStyle}"  # specify color theme
      c.JupyterQtConsoleApp.hide_menubar = True
      c.ConsoleWidget.font_size = ${toString cfg.fontSize}
      c.ConsoleWidget.scrollbar_visibility = False
      c.JupyterConsoleApp.confirm_exit = False
      c.IPythonWidget.gui_completion = 'ncurses'
    '';

    home.packages = with pkgs; [
      python
      jupyter
      python310Packages.ipython
      python310Packages.jupyter_console
      python310Packages.matplotlib-inline
      python310Packages.jupyter
      python310Packages.jupyter-core
      python310Packages.jupyter_server
      python310Packages.jupyterlab
      python310Packages.ipykernel
      python310Packages.qtconsole
      python310Packages.xcffib
      libstdcxx5
      zlib
      gcc
      glib
      qt5.qtbase
      qt5.qtwebengine
    ];

  };
}
