# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US"

# system TimeZone
export TZ="America/Chicago"

export PATH=~/.npm-global/bin:$PATH

# for openweather polybar module
export CITY="Huntsville, US"
export UNITS="imperial"
export SYMBOL="°"

# add geckodriver to my path for use in selenium
export PATH=$PATH:/home/mcamp/.geckodriver/

# for npm so we don't need sudo to install global stuff
export PATH=~/.npm-global/bin:$PATH

# export TERM='linux'

export GID=$(id -g)

# python scripts
export PATH=/home/mcamp/.local/bin:$PATH

# display socket for dockers to share
export XSOCK=/tmp/.X11-unix/X0

#docker socker
export DOCKER=/var/run/docker.sock
