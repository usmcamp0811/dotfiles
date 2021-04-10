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
# See https://wiki.archli
