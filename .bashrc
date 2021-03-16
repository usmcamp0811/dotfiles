#:highlight SignColumn guibg=darkgrey!/bin/bash
umask 022
# Change the window title of X terminals
case ${TERM} in
	xterm*|rxvt*|Eterm*|aterm|kterm|gnome*|interix|konsole*|urxvt*)
		PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
		;;
	screen*)
		PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
		;;
        esac
# source all the other bash config files
for file in ~/.config/bash/*.bashrc; do
    [ -r "$file" ] && source "$file"
done

# source my private config files
for file in ~/.config/bash/private/*.bashrc; do
    [ -r "$file" ] && source "$file"
done

[ -r "/usr/share/fzf/completion.bash" ] && source /usr/share/fzf/completion.bash
[ -r "/usr/share/fzf/key-bindings.bash" ] && source /usr/share/fzf/key-bindings.bash

complete -cf sudo
shopt -s checkwinsize
shopt -s expand_aliases
# Enable history appending instead of overwriting.  #139609
shopt -s histappend
# for making ctr-s and ctrl-q work in vim
bind -r '\C-s'
stty -ixon
xhost +local:root > /dev/null 2>&1
use_color=true


# powerline shell PS1
function _update_ps1() {
    PS1=$(powerline-shell $?)
}
# export TERM=notlinux
if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi
# gonna try to use tmux all the time
# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#   exec tmux
# fi

codi() {
   local syntax="${1:-python}"
   shift
   nvim -c \
     "let g:startify_disable_at_vimenter = 1 |\
     set bt=nofile ls=0 noru nonu nornu |\
     hi CodiVirtualText guifg=red
     hi ColorColumn ctermbg=NONE |\
     hi VertSplit ctermbg=NONE |\
     hi NonText ctermfg=0 |\
     Codi $syntax" "$@"
}

# I use arch btw...
[ -e /usr/bin/archey3 ] && archey3 --config ~/.config/archey3.cfg 
[ -e /usr/bin/thefuck ] && eval "$(thefuck --alias)"

source $HOME/.config/broot/launcher/bash/br

source /home/mcamp/.config/broot/launcher/bash/br
