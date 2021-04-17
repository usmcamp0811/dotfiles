#!/bin/sh

picom -b
feh --bg-scale /home/mcamp/.background
# /home/mcamp/.config/polybar/launch &
redshift-gtk &
bash ~/.local/bin/swap-capslock-esc.sh
# powertop --auto-tune &
xautolock -time 10 -locker i3lock-fancy &
# /home/mcamp/.local/bin/lid-action &
powertop --auto-tune &
nm-applet &
ckb-next-daemon &
ckb-next -b &
blueman-applet &

export GDK_SCALE=1.4
[[ $(xrandr --listactivemonitors | grep 1440) -eq 0 ]] && export GDK_SCALE=1 || export GDK_SCALE=1.33
# See https://wiki.archli
