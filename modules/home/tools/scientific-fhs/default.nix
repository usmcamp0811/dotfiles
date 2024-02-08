{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.tools.scientific-fhs;
  # inherit (inputs) scientific-fhs;
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
    
    campground.tools.julia.enable = mkForce false;
    campground.tools.python.enable = mkForce false;

    programs.scientific-fhs = {
      enable = true;
      # juliaVersions = [
      #   {
      #     version = "1.10.0";
      #     default = true;
      #   }
      # ];
      # enableNVIDIA = true;
      # enableGraphical = true;
    };
  };
}

