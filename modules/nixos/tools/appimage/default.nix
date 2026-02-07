{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.appimage;
in {
  options.fmf.tools.appimage = with types; {
    enable = mkBoolOpt false "Whether or not to enable common appimage-run.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [appimage-run];
    boot.binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
      magicOrExtension = "\\x7fELF....AI\\x02";
    };
  };
}
