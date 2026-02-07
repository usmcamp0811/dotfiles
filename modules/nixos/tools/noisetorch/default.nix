{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.noisetorch;
in
{
  options.fmf.tools.noisetorch = with types; {
    enable = mkBoolOpt false "Whether or not to enable noisetorch.";
  };

  config = mkIf cfg.enable { programs.noisetorch.enable = true; };
}
