{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.onepass;
in {
  options.fmf.apps.onepass = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable 1Password and 1Password-cli.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [_1password-gui _1password];
  };
}
