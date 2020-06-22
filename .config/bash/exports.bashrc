# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US"
# Default programs:
export EDITOR="nvim"
export TERMINAL="alacritty"
export BROWSER="brave"
export READER="zathura"
# system TimeZone
export TZ="America/Chicago"
export XDG_CACHE_HOME=$HOME/.cache

# for openweather polybar module
export CITY="Huntsville, US"
export UNITS="imperial"
export SYMBOL="°"

# add geckodriver to my path for use in selenium
export PATH=$PATH:$HOME/.geckodriver/

export GID=$(id -g)

# python scripts
export PATH=$HOME/.local/bin:$PATH

# display socket for dockers to share
export XSOCK=/tmp/.X11-unix/X0

#docker socker
export DOCKER=/var/run/docker.sock
export DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export NODE_REPL_HISTORY="$XDG_DATA_HOME"/node_repl_history
export NVM_DIR="$XDG_DATA_HOME"/nvm
export PYLINTHOME="$XDG_CACHE_HOME"/pylint
export PYTHON_EGG_CACHE="$XDG_CACHE_HOME"/python-eggs
export WGETRC="$XDG_CONFIG_HOME/wgetrc"
# makes man pages stay in the terminal when you exitthem
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export IPYTHONDIR="$XDG_CONFIG_HOME"/jupyter
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME"/jupyter
export PYTHON_EGG_CACHE="$XDG_CACHE_HOME"/python-eggs
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export GOPATH="$XDG_DATA_HOME/go"
# export INPUTRC="$XDG_CONFIG_HOME"/readline/inputrc
# for go
export PATH=$PATH:$GOPATH/bin
# export DOCKER_HOST=tcp://127.0.0.1:2376
# export DOCKER_TLS_VERIFY=1
# export DOCKER_CERT_PATH=~/.config/docker
