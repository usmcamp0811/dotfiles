#!/bin/sh

export GDK_SCALE=1.4
[[ "$(pgrep -x picom | wc -l)" != "1" ]] && picom --experimental-backend -b &
# /home/mcamp/.config/polybar/launch &
# [[ "$(pgrep -x redshift-gtk | wc -l)" != "1" ]] && redshift-gtk &
[[ "$(ps aux | grep redshift | wc -l)" != "1" ]] && redshift-gtk -l 34.6503:86.7757 -t 5700:3600 -g 0.8 -m randr -v &
xflux -z 35811
bash $HOME/.local/bin/swap-capslock-esc.sh
# powertop --auto-tune &
xautolock -time 10 -locker i3lock-fancy &
# /home/mcamp/.local/bin/lid-action &
powertop --auto-tune &
nm-applet &
ckb-next-daemon &
ckb-next -b &
blueman-applet &
optimus-manager-qt &
dunst &
# xinput set-button-map 18 1 0 3 &

[[ $(xrandr --listactivemonitors | grep 1440) -eq 0 ]] && export GDK_SCALE=1 || export GDK_SCALE=1.33

autorandr --change
feh --bg-scale $HOME/.background
# rogauracore blue
# See https://wiki.archli

#hide the mouse 
# xbanish &
