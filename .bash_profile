
[[ -f ~/.bashrc ]] && . ~/.bashrc

source /home/mcamp/.config/broot/launcher/bash/br

if [ -z "$DISPLAY" -a "$XDG_VTNR" -eq 1 ];
then 
    startx
fi
