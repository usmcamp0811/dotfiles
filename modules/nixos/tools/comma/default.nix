{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.comma;
in {
  options.campground.tools.comma = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Comma.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ comma ]; };
}
