{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.tools.scientific-fhs;
  inherit (inputs) scientific-fhs;
in
{
  options.campground.tools.scientific-fhs = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common Scientific FHS.";
  };

  imports = [ 
    inputs.scientific-fhs.nixosModules.default
  ];
  config = mkIf cfg.enable {
    
    # home.packages = with pkgs; [
    #   scientific-fhs
    #
    # ];

    # home.sessionVariables = {
    #   LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH";
    # };
    programs.scientific-fhs = {
      # enable = true;
      # juliaVersions = [
      #   {
      #     version = "julia_19";
      #     default = true;
      #   }
      # ];
      # enableNVIDIA = true;
    };
  };
}

