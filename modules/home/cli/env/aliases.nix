{ pkgs, ... }:
pkgs.writeText "aliases.nix" ''

  copy(){
      cat $1 | xsel -b
  }


  alias vim='${pkgs.campground-nvim}/bin/nvim'

  alias df='df -h'


  alias zathura='${pkgs.devour}/bin/devour ${pkgs.zathura}/bin/zathura'
  # alias feh='devour feh'
  alias weather='${pkgs.devour}/bin/devour weather'
  alias radar='${pkgs.devour}/bin/devour weather -r'
  alias neovide='${pkgs.devour}/bin/devour ${pkgs.neovide}/bin/neovide'


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
  alias diff='vim -d'

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




''
