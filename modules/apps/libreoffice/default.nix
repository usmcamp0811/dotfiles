{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.apps.libreoffice;
in
{
  options.campground.apps.libreoffice = with types; {
    enable = mkBoolOpt false "Whether or not to enable libreoffice.";
  };

  config = mkIf cfg.enable { 
    environment.systemPackages = with pkgs; [
      libreoffice-qt
      hunspell
      hunspellDicts.uk_UA
      hunspellDicts.th_TH
    ];
  };
}
