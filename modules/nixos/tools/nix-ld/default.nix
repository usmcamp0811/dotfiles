{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.nix-ld;
in
{
  options.campground.tools.nix-ld = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix-ld.";
  };

  config = mkIf cfg.enable { programs.nix-ld.enable = true; };
}
