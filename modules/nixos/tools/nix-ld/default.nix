{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.nix-ld;
in
{
  options.fmf.tools.nix-ld = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix-ld.";
  };

  config = mkIf cfg.enable { programs.nix-ld.enable = true; };
}
