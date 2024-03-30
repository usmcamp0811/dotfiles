{ config, lib, pkgs, ... }:
let
  inherit (lib) getExe getExe';

  githubHelper = pkgs.writeShellScriptBin "githubHelper" # bash
    ''
      #!/usr/bin/env bash

      NOTIFICATIONS="$(${getExe pkgs.gh} api notifications)"
      COUNT="$(echo "$NOTIFICATIONS" | ${getExe pkgs.jq} 'length')"

      echo '{"text":'"$COUNT"',"tooltip":"'"$COUNT"' Notifications","class":""}'
    '';
in {
  "custom/ellipses" = {
    "format" = "";
    "tooltip" = false;
  };

  # "custom/github" = {
  #   "format" = " {}";
  #   "return-type" = "json";
  #   "interval" = 60;
  #   "exec" = "${getExe githubHelper}";
  #   "on-click" = "${getExe' pkgs.coreutils "sleep"} 0.1 && ${getExe' pkgs.xdg-utils "xdg-open"} https://github.com/notifications";
  # };

  "custom/lock" = {
    "format" = "󰍁";
    "tooltip" = false;
    "on-click" = "${getExe config.programs.swaylock.package}";
  };

  # "custom/media" = {
  #   "format" = "{icon} {}";
  #   "return-type" = "json";
  #   "max-length" = 40;
  #   "format-icons" = {
  #     "spotify" = "";
  #     "default" = "🎜";
  #   };
  #   "escape" = true;
  #   "exec" = "$HOME/.config/waybar/mediaplayer.py 2> /dev/null";
  # };

  "custom/notification" = {
    "tooltip" = true;
    "format" = "{icon} {}";
    "format-icons" = {
      "notification" = "<span foreground='red'><sup></sup></span>";
      "none" = "";
      "dnd-notification" = "<span foreground='red'><sup></sup></span>";
      "dnd-none" = "";
      "inhibited-notification" = "<span foreground='red'><sup></sup></span>";
      "inhibited-none" = "";
      "dnd-inhibited-notification" =
        "<span foreground='red'><sup></sup></span>";
      "dnd-inhibited-none" = "";
    };
    "return-type" = "json";
    "exec-if" = "which ${getExe' pkgs.swaynotificationcenter "swaync-client"}";
    "exec" = "${getExe' pkgs.swaynotificationcenter "swaync-client"} -swb";
    "on-click" = "${getExe' pkgs.coreutils "sleep"} 0.1 && ${
        getExe' pkgs.swaynotificationcenter "swaync-client"
      } -t -sw";
    "on-click-right" = "${getExe' pkgs.coreutils "sleep"} 0.1 && ${
        getExe' pkgs.swaynotificationcenter "swaync-client"
      } -d -sw";
    "escape" = true;
  };

  "custom/power" = {
    "format" = "";
    "tooltip" = false;
    "on-click" = "shutdown now";
  };

  "custom/reboot" = {
    "format" = "󰜉";
    "tooltip" = false;
    "on-click" = "reboot";
  };

  "custom/separator-right" = {
    "format" = "";
    "tooltip" = false;
  };

  "custom/separator-left" = {
    "format" = "";
    "tooltip" = false;
  };

  "custom/weather" = {
    "exec" = ''
      ${getExe pkgs.wttrbar} --location "$(${
        getExe pkgs.curl
      } -s 'wttr.in?format=%l')" --fahrenheit --main-indicator temp_F'';
    "return-type" = "json";
    "format" = "{}";
    "tooltip" = true;
    "interval" = 3600;
  };

  "custom/wlogout" = {
    "format" = "";
    "interval" = "once";
    "tooltip" = false;
    "on-click" = "${getExe' pkgs.coreutils "sleep"} 0.1 && ${
        getExe pkgs.wlogout
      } -c 5 -r 5 -p layer-shell";
  };
}
