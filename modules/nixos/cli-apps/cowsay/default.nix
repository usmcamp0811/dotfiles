{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli-apps.cowsay;
in
{
  options.fmf.cli-apps.cowsay = with types; {
    enable = mkBoolOpt false "Whether or not to enable cowsay.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ pkgs.cowsay ];
  };
}
