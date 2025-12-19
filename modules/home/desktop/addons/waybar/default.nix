{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.waybar;

  theme = builtins.readFile ./styles/catppuccin.css;
  style = builtins.readFile ./styles/style.css;
  notificationsStyle = builtins.readFile ./styles/notifications.css;
  powerStyle = builtins.readFile ./styles/power.css;
  statsStyle = builtins.readFile ./styles/stats.css;
  workspacesStyle = builtins.readFile ./styles/workspaces.css;

  custom-modules =
    import ./modules/custom-modules.nix {inherit config lib pkgs;};
  default-modules = import ./modules/default-modules.nix {inherit lib pkgs;};
  group-modules = import ./modules/group-modules.nix;
  hyprland-modules =
    import ./modules/hyprland-modules.nix {inherit config lib;};

  all-modules = mkMerge [
    custom-modules
    default-modules
    group-modules
    (lib.mkIf config.fmf.desktop.hyprland.enable hyprland-modules)
  ];

  bar = {
    "layer" = "top";
    "position" = "top";

    "margin-top" = 10;
    "margin-left" = 20;
    "margin-right" = 20;

    "modules-left" = [
      "group/power"
      "hyprland/workspaces"
      "custom/separator-left"
      "hyprland/window"
    ];
  };

  # TODO: make bars an option that gets passed in maybe so you can specify multiple monitors
  mainBar = {
    # "output" = cfg.display;
    # "modules-center" = [ "mpris" ];

    "modules-right" = [
      "group/tray"
      "custom/separator-right"
      "group/stats"
      "custom/separator-right"
      "group/notifications"
      "hyprland/submap"
      "custom/weather"
      "clock"
    ];
  };
in {
  options.fmf.desktop.addons.waybar = with types; {
    enable =
      mkBoolOpt false "Whether to enable gBar in the desktop environment.";
    display = mkOpt str "DP-1" "the name of the output";
  };

  config = mkIf cfg.enable {
    # systemd.user.services.waybar.Service.ExecStart = mkIf cfg.debug (mkForce "${getExe config.programs.waybar.package} -l debug");

    programs.waybar = {
      enable = true;
      # package = nixpkgs-wayland.packages.${system}.waybar;
      package = pkgs.waybar;
      systemd.enable = true;

      # TODO: make dynamic / support different number of bars etc
      settings = {
        mainBar = mkMerge [bar mainBar all-modules];
        # secondaryBar = mkMerge [ bar secondaryBar all-modules ];
      };

      style = "${theme}${style}${notificationsStyle}${powerStyle}${statsStyle}${workspacesStyle}";
    };
  };
}
