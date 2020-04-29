#!/bin/bash


# Easier navigation: .., ..., ~ and -
alias ..="cd .."
alias cd..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# ls -al Alh
alias ls="lsd --group-dirs first"
alias la="lsd -laF --group-dirs first"
alias lh='lsd -ls --group-dirs first'
alias lt='lsd --tree --depth 3'

# mv, rm, cp
alias mv='mv -v'
alias rm='rm -i -v'
alias cp='cp -v'


alias chmox='chmod -x'
alias cat='bat'

alias vim='nvim'

alias df='df -h'

alias grep='grep --color=auto'

##########################################################
####################### GIT STUFF ########################

function clone() {
    git clone --depth=1 $1
    cd $(basename ${1%.*})
    yarn install
}
alias push="git push"

# Undo a `git push`
alias undopush="git push -f origin HEAD^:master"

# git root
alias gr='[ ! -z `git rev-parse --show-cdup` ] && cd `git rev-parse --show-cdup || pwd`'
alias master="git checkout master"

# git dotfiles
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

##########################################################
####################### CONFIG STUFF ########################
#i3 config
alias i3config='/usr/bin/nvim ~/.config/i3/config'

#bash aliases
alias aliases='/usr/bin/nvim ~/.config/bash/aliases.bashrc'

#bash export
alias exports='/usr/bin/nvim ~/.config/bash/exports.bashrc'

#vim plugins
alias vplug='/usr/bin/nvim ~/.config/nvim/load_plugins.vim'
alias vplug2='/usr/bin/nvim ~/.config/nvim/config_plugins.vim'
alias vkeys='/usr/bin/nvim ~/.config/nvim/key-mappings.vim'
alias vgen='/usr/bin/nvim ~/.config/nvim/general.vim'
alias vinit='/usr/bin/nvim ~/.config/nvim/init.vim'

##########################################################
# Empty the Trash on all mounted volumes and the main HDD. then clear the useless sleepimage
alias emptytrash=" \
    sudo rm -rfv /Volumes/*/.Trashes; \
    rm -rfv ~/.Trash/*; \
    sudo rm -v /private/var/vm/sleepimage; \
    rm -rv \"/Users/paulirish/Library/Application Support/stremio/Cache\";  \
    rm -rv \"/Users/paulirish/Library/Application Support/stremio/stremio-cache\" \
"
# stop and rm docker
# function kill-docker() {
  # docker stop $1 && docker rm $1
# }

alias vimwiki="/usr/bin/nvim +VimwikiIndex NERDTreeClose"

alias tmux="tmux -f ${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"

new-tmux(){
  tmux new -s $1
}

my-tmux(){
  tmux a -t $
}

# yea i am sick of typing allthat.. 
alias update="sudo pacman -Syu"

# fix pacman when it doesn't finish installing
alias fix-pacman="sudo rm /var/lib/pacman/db.lck"

# fix pulseadudio
function fix-audio(){
  pulseaudio -k
  sleep 2
  pulseaudio
}

save-gnome(){
    # saves gnome settings to file 
    echo "Saving gnome settings to ~/.config/dconf/dconf-settings.ini"
    dconf dump / > ~/.config/dconf/dconf-settings.ini
}
load-gnome(){
    # load gnome settings from file 
    echo "Loading gnome settings from ~/.config/dconf/dconf-settings.ini"
    dconf load / < ~/.config/dconf/dconf-settings.ini
}

new_tmux () {
  tmux new -s $1
}

a_tmux () {
  tmux a -t $1
}

kill () {
    [ $# -eq 0 ] && echo "You need to specify whom to kill." && return
    /usr/bin/kill $@
}
alias wget='wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'
