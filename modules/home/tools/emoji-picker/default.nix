{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.emoji-picker;
emoji-list = ./emoji;
emoji-picker = pkgs.writeShellScript "emoji-picker" ''
#!/bin/sh

# The famous "get a menu of emojis to copy" script.

# Get user selection via dmenu from emoji file.
chosen=$(cut -d ';' -f1 ${emoji-list} | ${pkgs.rofi}/bin/rofi -dmenu | sed "s/ .*//")

# Exit if none chosen.
[ -z "$chosen" ] && exit

# If you run this command with an argument, it will automatically insert the
# character. Otherwise, show a message that the emoji has been copied.
if [ -n "$1" ]; then
    ${pkgs.xdotool}/bin/xdotool type "$chosen"
else
    printf "$chosen" | ${pkgs.xclip}/bin/xclip -selection clipboard
    ${pkgs.notify-send}/bin/notify-send "'$chosen' copied to clipboard." &
fi
'';
in
{
  options.campground.tools.emoji-picker = with types; {
    enable = mkBoolOpt false "Whether or not to enable emoji-picker.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      emoji-picker
    ];
  };
}
