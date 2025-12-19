{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.tools.television;
in {
  options.fmf.tools.television = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Television.";
  };

  config = mkIf cfg.enable { home.packages = with pkgs; [ television ]; };
}
