{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.node;
in {
  options.campground.tools.node = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Node.";
  };

  config = mkIf cfg.enable {

    # home.packages = with pkgs; [ nodesjs yarn ];

  };
}
