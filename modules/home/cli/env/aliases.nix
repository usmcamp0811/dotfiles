{ pkgs, ... }:
pkgs.writeText "aliases.nix" ''
  # Nix Did this!!
  # Easier navigation: .., ..., ~ and -
  alias ..="cd .."
  alias cd..="cd .."
  alias ...="cd ../.."
  alias ....="cd ../../.."
  alias .....="cd ../../../.."
  alias ~="cd ~" # `cd` is probably faster to type though
  alias -- -="cd -"


  # ls -al Alh

  alias ls="${pkgs.lsd}/bin/lsd --group-dirs first"
  alias la="${pkgs.lsd}/bin/lsd -laF --group-dirs first"
  alias lt='${pkgs.lsd}/bin/lsd --tree --depth 3'                              


  # mv, rm, cp
  alias mv='mv -v'
  alias rm='rm -i -v'
  alias cp='cp -v'

  copy(){
      cat $1 | xsel -b
  }


  alias chmox='chmod -x'
  alias cat='${pkgs.bat}/bin/bat'
  alias pcat='${pkgs.bat}/bin/bat -p'
  alias vim='${pkgs.campground-nvim}/bin/nvim'

  alias df='df -h'

  alias grep='grep --color=auto'

  alias zathura='${pkgs.devour}/bin/devour ${pkgs.zathura}/bin/zathura'
  # alias feh='devour feh'
  alias mpv='${pkgs.devour}/bin/devour mpv --script=$HOME/.config/mpv/scripts/mpv-cheatsheet.js -ao=pipewire'
  alias weather='${pkgs.devour}/bin/devour weather'
  alias radar='${pkgs.devour}/bin/devour weather -r'
  alias neovide='${pkgs.devour}/bin/devour ${pkgs.neovide}/bin/neovide'

  ##########################################################
  ####################### GIT STUFF ########################

  alias push="${pkgs.git}/bin/git push"
  alias gs="${pkgs.git}/bin/git status"
  # Undo a `git push`
  alias undopush="${pkgs.git}/bin/git push -f origin HEAD^:master"

  # git root
  alias gr='[ ! -z `${pkgs.git}/bin/git rev-parse --show-cdup` ] && cd `${pkgs.git}/bin/git rev-parse --show-cdup || pwd`'
  alias master="${pkgs.git}/bin/git checkout master"

  ##########################################################
  ####################### CONFIG STUFF ########################
  #i3 config
  alias i3config='nvim ~/.config/i3/config'
  alias qconfig='vim ~/.config/qtile/config.py'

  #bash aliases
  alias aliases='nvim ~/.config/shell/aliases.shrc'

  #bash export
  alias exports='nvim ~/.config/shell/exports.shrc'

  ##########################################################
  alias tmux="${pkgs.tmux}/bin/tmux -f ''${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  alias wget='${pkgs.wget}/bin/wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'
  alias nvidia-settings='nvidia-settings --config="$XDG_CONFIG_HOME"/nvidia/settings'
  alias gpg2='${pkgs.gnupg}/bin/gpg2 --homedir "$XDG_DATA_HOME"/gnupg'
  alias freecad='freecad -u "$XDG_CONFIG_HOME"/FreeCAD/user.cfg -s "$XDG_CONFIG_HOME"/FreeCAD/system.cfg'
  alias gpg2='gpg2 --homedir "$XDG_DATA_HOME"/gnupg'
  alias weechat='weechat -d "$XDG_CONFIG_HOME"/weechat'
  alias cura="QT_SCALE_FACTOR=1 cura"
  alias weather='~/.local/bin/weather'
  alias outdoor='xcalib -invert -alter'
  alias night='rogauracore black'
  alias code='cd ~/code'
  alias k='kubectl'
  alias kwatch='watch kubectl'
  alias diff='vim -d'
  alias nvim-dir="cd ~/.config/nvim/"
  alias vimconfig="vim ~/.config/nvim/init.lua"
  alias vimplug="vim ~/.config/nvim/lua/user/plugins.lua"
  alias status='sudo systemctl status'
  alias start='sudo systemctl start'
  alias stop='sudo systemctl stop'
  alias restart='sudo systemctl restart'
  alias disable='sudo systemctl disable'
  alias enable='sudo systemctl enable'

  ## Functions

  function clone() {
      git clone --depth=1 $1
      cd $(basename ''${1%.*})
  }

  function dkill() {
      ${pkgs.docker}/bin/docker stop $1 && ${pkgs.docker}/bin/docker rm $1
  }

  function docker-login() {
      ${pkgs.docker}/bin/docker login -u $DHUB_USER -p $DHUB_PASS
  }

  new_tmux () {
      ${pkgs.tmux}/bin/tmux new -s $1
  }

  a_tmux () {
      ${pkgs.tmux}/bin/tmux a -t $1
  }

  fetch() {
      git fetch --all && git pull --all && git branch -r | grep -v '\->' | while read remote; do git branch --track "''${ remote # origin/}" "$remote"; done
      }

  kill () {
      [ $# -eq 0 ] && echo "You need to specify whom to kill." && return
      /usr/bin/kill $@
  }


  gpu-hybrid(){
      supergfxctl --mode hybrid
      sudo pkill -9 -u $USER
  }

  gpu-dedicated(){
      supergfxctl --mode dedicated
      sudo pkill -9 -u $USER
  }


  # convert "Channel Name" "https://youtube.com/@somechannel" to ytdl-sub yaml
  function subscribe(){
    channelname=$1
    url=$2
    channelidurl=$(yt-channelid "$url")
    safename=$(echo "$url" | sed 's/^.*@//')

  printf \
  $safename':
    preset:
      - "yt_channel"
      - "recent_videos"
    download:
      url: "'$channelidurl'"
    overrides:
      tv_show_name: "'$channelname'"


  '
  }

  # convert youtube channel url with @channelname to the channel id for ytdl-sub
  function yt-channelid(){
    echo $(curl $1 | grep '^.*"channelUrl"' | sed 's/^.*"channelUrl":"//g' | sed 's/",.*$//g')
  }

  function dl_music(){
    yt-dlp -x --audio-format mp3 $1 --write-thumbnail --add-metadata --embed-thumbnail --cookies-from-browser brave
  }

  fix-pipewire(){
    systemctl --user restart pipewire-pulse.service
    systemctl --user restart wireplumber.service
  }

  update-user(){
    nix run /config/\#homeConfigurations.''${USER}@ldap.activationPackage
  }

  update-sys(){
    sudo sh -c 'nixos-rebuild switch --flake /config/#$(hostname) |& nom'
  }

  get-approle() {          
    local role_id=$(sudo cat /var/lib/vault/$(hostname)/role-id)
    local secret_id=$(sudo cat /var/lib/vault/$(hostname)/secret-id)
    export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id="$role_id" secret_id="$secret_id")
  }

  zsh-unlock() {
    HOST=$1
    ssh root@$HOST "zpool import -a; zfs load-key -a && killall zfs"
  }

''
