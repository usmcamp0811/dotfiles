{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.tools.python;
in
{
  options.campground.tools.python = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Python.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      python
    ];
  };
}
