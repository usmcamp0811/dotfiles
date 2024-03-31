{ lib, writeShellScriptBin, docker }:

writeShellScriptBin "mac-nix" ''
  #!/usr/bin/env bash
  # This script wraps Nix commands to run inside a Docker container for compatibility with macOS.

  # Ensure Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Docker does not seem to be running, please start Docker first."
    exit 1
  fi

  # Initialize an empty array for positional arguments
  declare -a POSITIONAL_ARGS=()

  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --env)
        ENV_FILE_ARG="--env-file $2"
        shift # past argument
        shift # past value
        ;;
      *)    # unknown option
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
  done
  
  # Set positional arguments back
  set -- "''${POSITIONAL_ARGS[@]}"

  # Run the Nix command in the nixpkgs/nix-flakes Docker container
  docker run -it --rm \
    ''${ENV_FILE_ARG:-} \
    --volume "$PWD:/build" \
    --volume "/nix:/nix:ro" \
    --workdir "/build" \
    --entrypoint nix nixpkgs/nix-flakes "$@"
''

