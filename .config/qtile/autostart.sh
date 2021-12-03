#!/bin/sh

export GDK_SCALE=1.4
[[ "$(pgrep -x picom | wc -l)" != "1" ]] && picom --experimental-backend -b &
feh --bg-scale /home/mcamp/.background
# /home/mcamp/.config/polybar/launch &
# [[ "$(pgrep -x redshift-gtk | wc -l)" != "1" ]] && redshift-gtk &
# [[ "$(ps aux | grep redshift | wc -l)" != "1" ]] && redshift-gtk -l 34.6503:86.7757 -t 5700:3600 -g 0.8 -m randr -v &
xflux -z 35811
bash ~/.local/bin/swap-capslock-esc.sh
# powertop --auto-tune &
xautolock -time 10 -locker i3lock-fancy &
# /home/mcamp/.local/bin/lid-action &
powertop --auto-tune &
nm-applet &
ckb-next-daemon &
ckb-next -b &
blueman-applet &
dunst &

[[ $(xrandr --listactivemonitors | grep 1440) -eq 0 ]] && export GDK_SCALE=1 || export GDK_SCALE=1.33

# autorandr -c
rogauracore blue
# See https://wiki.archli
