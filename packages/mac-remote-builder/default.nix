{ pkgs, ... }:
let
  src = ./.;
  docker-image-name = "nix-remote-builder";

  stop-builder = pkgs.writeShellScriptBin "stop" ''
    ${pkgs.docker}/bin/docker stop ${docker-image-name}
  '';

  build-image = pkgs.writeShellScriptBin "build" ''
    AUTHORIZED_KEY=''${1:-"$(cat $HOME/.ssh/*.pub)"}
    ${pkgs.docker}/bin/docker build -f ${src}/Dockerfile -t nix-builder --build-arg AUTHORIZED_KEY="$AUTHORIZED_KEY" .
  '';

  start-builder = pkgs.writeShellScriptBin "start-builder" ''
    ACCESS_TOKENS=${1}
    PORT=${"2:-2222"}
    NETRC_FILE=${"3:-" "$HOME/.netrc"}

    # Create a temporary directory for the nix.conf file
    TEMP_DIR=$(mktemp -d)
    NIX_CONF="$TEMP_DIR/nix.conf"

    echo "accept-flake-config = true" > $NIC_CONF
    echo "experimental-features = nix-command flakes" >> $NIC_CONF

    if [ -n "$ACCESS_TOKENS" ]; then
      echo "access-tokens = $ACCESS_TOKENS" >> $NIC_CONF
    fi

    ${pkgs.docker}/bin/docker run -it -p $PORT:22 \
      -n ${docker-image-name} \
      -v $NIX_CONF:/etc/nix/nix.conf:ro \
      -v $NETRC_FILE:/root/.netrc:ro \
      nix-builder
  '';

  readme = pkgs.writeShellScriptBin "readme" ''
    ${pkgs.bat}/bin/bat ${src}/README.md
  '';
in readme // {
  build = build-image;
  start = start-builder;
  stop = stop-builder;
}
