#!/bin/sh
xmodmap -e "clear lock" &
xmodmap -e "keycode 9 = Caps_Lock NoSymbol Caps_Lock" &
xmodmap -e "keycode 66 = Escape NoSymbol Escape" &

# wait 30
notify-send "Keyboard" "$(whoami) your Keyboard was detected and Escape has been swapped with Caps Lock"
# [[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap
