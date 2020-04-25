#:highlight SignColumn guibg=darkgrey!/bin/bash
# I use arch btw...
archey3
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

eval "$(thefuck --alias)"
