{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.waybar;
in
{
  options.campground.desktop.addons.waybar = with types; {
    enable =
      mkBoolOpt false "Whether to enable gBar in the desktop environment.";
  };

  config = mkIf cfg.enable {
    systemd.user.services.waybar.Service.ExecStart = mkIf cfg.debug (mkForce "${getExe config.programs.waybar.package} -l debug");

    programs.waybar = {
      enable = true;
      # package = nixpkgs-wayland.packages.${system}.waybar;
      package = pkgs.waybar;
      systemd.enable = true;

      # TODO: make dynamic / support different number of bars etc
      settings = {
        mainBar = mkMerge [ bar mainBar all-modules ];
        secondaryBar = mkMerge [ bar secondaryBar all-modules ];
      };

      # style = "${theme}${style}${notificationsStyle}${powerStyle}${statsStyle}${workspacesStyle}";
    }; 
  };
}

