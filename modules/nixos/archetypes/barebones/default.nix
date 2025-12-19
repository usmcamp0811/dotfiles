{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.barebones;
in
{
  options.fmf.archetypes.barebones = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the barebones archetype.";
  };

  config =
    mkIf cfg.enable { fmf = { suites = { common = enabled; }; }; };
}
