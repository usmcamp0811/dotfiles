{ inputs
, options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.gbar;
  inherit (inputs) gBar;
in
{
  options.fmf.desktop.addons.gbar = with types; {
    enable =
      mkBoolOpt false "Whether to enable gBar in the desktop environment.";
  };
  imports = [ inputs.gBar.homeManagerModules.x86_64-linux.default ];
  config = mkIf cfg.enable {
    programs.gBar = {
      enable = true;
      config = {
        Location = "L";
        EnableSNI = true;
        SNIIconSize = {
          Discord = 26;
          OBS = 23;
        };
        WorkspaceSymbols = [ " " " " ];
      };
    };
  };
}
