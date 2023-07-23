{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.openssh;
in
{
  options.campground.services.cac = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pcsclite
      opensc
      ccid
    ];

   services.pcscd.enable = true;

  };
}
