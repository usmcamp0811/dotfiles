{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.tools.comma;
in {
  options.fmf.tools.comma = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Comma.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ comma ]; };
}
