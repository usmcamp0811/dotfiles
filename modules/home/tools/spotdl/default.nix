{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.tools.spotdl;

  queue_file = "$HOME/.bdl_queue";

  bdl = pkgs.writeShellScriptBin "bdl" ''
    queue_file="$HOME/.bdl_queue"
    mkdir -p "$(dirname "$queue_file")"
    touch "$queue_file"

    if [ "$#" -eq 1 ]; then
      echo "$1" >> "$queue_file"
      echo "URL queued: $1"
      exit 0
    fi

    tmpdir=$(mktemp -d) || { echo "Failed to create temporary directory"; exit 1; }
    cd "$tmpdir" || { echo "Failed to change directory to $tmpdir"; exit 1; }

    while true; do
      if [ ! -s "$queue_file" ]; then
        echo "Queue is empty. Exiting."
        rm -r "$tmpdir"
        exit 0
      fi

      url=$(head -n 1 "$queue_file")
      sed -i '1d' "$queue_file"

      echo "Downloading: $url"
      ${pkgs.spotdl}/bin/spotdl "$url"

      if [ $? -eq 0 ]; then
        echo "Download complete for $url. Running 'beet im -m $tmpdir'..."
        ${pkgs.beets}/bin/beet im -m "$tmpdir"
      else
        echo "Download failed for $url. Skipping."
      fi
    done
  '';
in
{
  options.fmf.tools.spotdl = with types; {
    enable = mkBoolOpt false "Whether or not to enable spotdl.";
  };

  config = mkIf cfg.enable { home.packages = [ bdl ]; };
}
