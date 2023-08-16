{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.vmware;
in
{
  options.campground.apps.vmware = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vmware-workstation
    ];
  };
}
