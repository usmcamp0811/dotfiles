{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.remmina;
in
{
  options.fmf.tools.remmina = with types; {
    enable = mkBoolOpt false "Whether or not to enable Remmina.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ remmina ];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "application/x-rdp" = "org.remmina.Remmina.desktop";
    };

    xdg.desktopEntries.remmina = {
      name = "Remmina";
      exec = "${pkgs.bash}/bin/bash -c \"G_MESSAGES_DEBUG=all ${pkgs.remmina}/bin/remmina -c %u\"";
      type = "Application";
      mimeType = [ "application/x-rdp" ];
      noDisplay = true;
    };
  };
}
