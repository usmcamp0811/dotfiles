{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "emoji-picker";

  owner = "Matt Camp";
  repo = pname;
  description = "Luke Smith's Emoji Picker converted to use Rofi and ported to Nix";
  version = "0.1.0";

  emojis = builtins.readFile ./emojis;

  emoji-script = pkgs.writeShellScript "emoji-picker" ''
  #!/bin/sh

  # The famous "get a menu of emojis to copy" script.

  # Get user selection via dmenu from emoji file.
  chosen=$(cut -d ';' -f1 ${emojis} | ${pkgs.rofi}/bin/rofi -dmenu | sed "s/ .*//")

  # Exit if none chosen.
  [ -z "$chosen" ] && exit

  # If you run this command with an argument, it will automatically insert the
  # character. Otherwise, show a message that the emoji has been copied.
  if [ -n "$1" ]; then
      ${pkgs.xdotool}/bin/xdotool type "$chosen"
  else
      printf "$chosen" | ${pkgs.xclip}/bin/xclip -selection clipboard
      ${pkgs.inotify-tools}/bin/notify-send "'$chosen' copied to clipboard." &
  fi
  '';

  emoji-picker = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    installPhase = ''
      cp ${emoji-script} $out/bin/'${pname}'
      chmod +x $out/bin/'${pname}'
    ''; 
  };

  new-meta = with lib; {
    description = description;
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
# {
#   # If k0s should be in the PATH:
#   # environment.systemPackages = [ k0s ];
#
# }
override-meta new-meta emoji-picker
