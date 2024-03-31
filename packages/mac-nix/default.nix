{ lib, writeShellScriptBin, pkgs }:

writeShellScriptBin "mac-nix" ''
  #!/usr/bin/env bash
  # This script wraps Nix commands to run inside a Docker container for compatibility with macOS.

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
  set -- "${POSITIONAL_ARGS[@]}"

  # Form the command string to execute inside the container
  COMMAND_STR="nix $@; if [ -e /build/result ]; then cp -r /build/result /build/nix-result; fi"

  # Run the command in the nixpkgs/nix-flakes Docker container and handle result copying
  ${pkgs.podman}/bin/podman run -it --rm \
    ${ENV_FILE_ARG:-} \
    --volume "$PWD:/build" \
    --workdir "/build" \
    --entrypoint bash nixpkgs/nix-flakes -c "$COMMAND_STR"
''
