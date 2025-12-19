{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.tools.julia;
in {
  options.fmf.tools.julia = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Julia.";
  };

  config =
    mkIf cfg.enable { home.packages = with pkgs; [ fmf.julia.fhs ]; };
}
