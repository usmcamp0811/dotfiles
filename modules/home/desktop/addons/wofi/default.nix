{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.wofi;
in {
  options.fmf.desktop.addons.wofi = with types; {
    enable =
      mkBoolOpt false "Whether to enable the Wofi in the desktop environment.";
  };

  config = mkIf cfg.enable {
    programs.wofi = {
      enable = true;
      settings = {
        location = "bottom-right";
        allow_markup = true;
        width = 650;
        hide_scroll = true;
        prompt = "";
        no_actions = true;
      };
      style = ''
        @define-color accent #b4befe;
        @define-color txt #b4befe;
        @define-color bg #181825;
        @define-color bg2 #1e1e2e;
        * {
            font-family: 'CaskaydiaCove Nerd Font mono';
            font-size: 12px;
         }

         /* Window */
         window {
            margin: 0px;
            padding: 8px;
            border-radius: 8px;
            background-color: @bg;
         }

         /* Inner Box */
         #inner-box {
            margin: 5px;
            padding: 10px;
            border: none;
            border-radius: 5px;
            background-color: @bg;
         }

         /* Outer Box */
         #outer-box {
            margin: 5px;
            padding: 10px;
            border: none;
            background-color: @bg;
            border-radius: 5px;
         }

         /* Scroll */
         #scroll {
            margin: 0px;
            padding: 10px;
            border: none;
         }

         /* Input */
         #input {
            margin: 5px;
            padding: 10px;
            border: none;
            color: @accent;
            background-color: @bg;
            border: 2px solid @accent;
         }

         /* Text */
         #text {
            margin: 5px;
            padding: 10px;
            border: none;
            color: @txt;
         }

         /* Selected Entry */
         #entry:selected {
           background-color: @bg;
           outline: 1px solid @accent;
         }

         #entry:selected #text {
            color: @txt;
         }
         image {
           margin-left: 10px;
         }

      '';
    };

    home.packages = with pkgs; [wofi-emoji];
  };
}
