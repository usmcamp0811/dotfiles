{ pkgs, ... }:
let
  src = ./.;
  docker-image-name = "nix-remote-builder";

  stop-builder = pkgs.writeShellScriptBin "stop" ''
    ${pkgs.docker}/bin/docker stop ${docker-image-name}
    ${pkgs.docker}/bin/docker rm ${docker-image-name}
  '';

  build-image = pkgs.writeShellScriptBin "build" ''
    AUTHORIZED_KEY=''${1:-"$(cat $HOME/.ssh/*.pub)"}
    ${pkgs.docker}/bin/docker build -f ${src}/Dockerfile -t nix-builder --build-arg AUTHORIZED_KEY="$AUTHORIZED_KEY" .
  '';

  start-builder = pkgs.writeShellScriptBin "start-builder" ''
    # Default values
    ACCESS_TOKENS=""
    PORT=2222
    NETRC_FILE="$HOME/.netrc"
    ADDITIONAL_PORTS=""

    # Parse named arguments
    while [ $# -gt 0 ]; do
      case "$1" in
        --access-tokens=*)
          ACCESS_TOKENS="''${1#*=}"
          shift
          ;;
        --port=*)
          PORT="''${1#*=}"
          shift
          ;;
        --netrc-file=*)
          NETRC_FILE="''${1#*=}"
          shift
          ;;
        --additional-ports=*)
          ADDITIONAL_PORTS="''${1#*=}"
          shift
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    # Create a temporary directory for the nix.conf file
    TEMP_DIR=$(mktemp -d)
    NIX_CONF="$TEMP_DIR/nix.conf"

    echo "accept-flake-config = true" > $NIX_CONF
    echo "experimental-features = nix-command flakes" >> $NIX_CONF

    if [ -n "$ACCESS_TOKENS" ]; then
      echo "access-tokens = $ACCESS_TOKENS" >> $NIX_CONF
    fi

    # Build the additional ports option
    PORT_OPTIONS=""
    if [ -n "$ADDITIONAL_PORTS" ]; then
      IFS=',' read -ra PORT_ARRAY <<< "$ADDITIONAL_PORTS"
      for port in "''${PORT_ARRAY[@]}"; do
        PORT_OPTIONS="$PORT_OPTIONS -p $port"
      done
    fi

    # Run the Docker container with all specified options
    ${pkgs.docker}/bin/docker run -it -d -p $PORT:22 \
      $PORT_OPTIONS \
      --name ${docker-image-name} \
      -v $NIX_CONF:/etc/nix/nix.conf:ro \
      -v $NETRC_FILE:/root/.netrc:ro \
      nix-builder

    ${host-config}/bin/config $PORT
  '';

  readme = pkgs.writeShellScriptBin "readme" ''
    ${pkgs.bat}/bin/bat ${src}/README.md
  '';

  host-config = pkgs.writeShellScriptBin "config" ''
    # Set the IP address or hostname of the running Docker container
    BUILDER_HOST="localhost"
    BUILDER_PORT=$1

    # Define the builder configuration string
    NIX_BUILDERS_CONFIG="builders = ssh://root@$BUILDER_HOST:$BUILDER_PORT;"

    # Create the Nix configuration directory if it doesn't exist
    mkdir -p ~/.config/nix

    # Path to the nix.conf file
    NIX_CONF_PATH="$HOME/.config/nix/nix.conf"

    # Check if the configuration is already present
    if grep -qF "$NIX_BUILDERS_CONFIG" "$NIX_CONF_PATH"; then
      echo "Remote builder configuration is already present in nix.conf."
    else
      # Append the configuration if it isn't already there
      echo "$NIX_BUILDERS_CONFIG" >> "$NIX_CONF_PATH"
      echo "Remote builder configuration added to nix.conf."
    fi
  '';
in readme // {
  build = build-image;
  start = start-builder;
  stop = stop-builder;
}
