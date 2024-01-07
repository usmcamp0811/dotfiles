{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.scientific-fhs;
  inherit (pkgs.campground) scientific-fhs-wrapped;
in
{
  options.campground.tools.scientific-fhs = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Scientific FHS.";
  };

  config = mkIf cfg.enable {
    
    # home.sessionVariables = {
    #   LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH";
    # };
    programs.scientific-fhs = {
      enable = true;
      juliaVersions = [
        {
          version = "julia_18";
          default = true;
        }
        { version = "julia_17"; }
        { version = "julia_16"; }
      ];
      enableNVIDIA = true;
    };
  };
}

