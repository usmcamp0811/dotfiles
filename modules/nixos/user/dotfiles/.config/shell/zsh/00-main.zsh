setopt PROMPT_SUBST

COMPLETION_WAITING_DOTS="true"


# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.cache/zsh/history

autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)

# use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# edit line in vim with ctrl-e
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line

# Change cursor shape for different vi modes.
function zle-keymap-select () {
    case $KEYMAP in
        vicmd) echo -ne '\e[1 q';;      # block
        viins|main) echo -ne '\e[5 q';; # beam
    esac
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.


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

# if we don't have the fzf stuff go get it
# ([ -r "/usr/share/fzf/completion.zsh" ] || [ -r "$HOME/.config/fzf/completion.zsh" ]) || $HOME/.local/bin/get-fzf-scripts
# ([ -r "/usr/share/fzf/key-bindings.zsh" ] || [ -r "$HOME/.config/fzf/key-bindings.zsh" ]) || $HOME/.local/bin/get-fzf-scripts
[ -r "/usr/share/fzf/completion.zsh" ] && source /usr/share/fzf/completion.zsh
[ -r "/usr/share/fzf/key-bindings.zsh" ] && source /usr/share/fzf/key-bindings.zsh
[ -r "$HOME/.config/fzf/completion.zsh" ] && source $HOME/.config/fzf/completion.zsh
[ -r "$HOME/.config/fzf/key-bindings.zsh" ] && source $HOME/.config/fzf/key-bindings.zsh

# export TERM=notlinux
if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi

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
# [ -e /usr/bin/thefuck ] && eval "$(thefuck --alias)"


# source $HOME/.config/broot/launcher/bash/br
[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2 >/dev/null
[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2 >/dev/null
[ -r $HOME/.local/share/alias-tips/alias-tips.plugin.zsh ] && source $HOME/.local/share/alias-tips/alias-tips.plugin.zsh 2 >/dev/null

function tvim() {
   printf '\e]710;%s\007' "FONT-FOR-VIM"
   /usr/bin/vim "$@"
   printf '\e]710;%s\007' "YOUR-DEFAULT-FONT"
}

# source /home/mcamp/.config/broot/launcher/bash/br
#TODO: figure this out
# something overwrites this so its here for now
alias diff='vim -d'

[ -e /usr/bin/bw ] && eval "$(bw completion --shell zsh); compdef _bw bw;"

