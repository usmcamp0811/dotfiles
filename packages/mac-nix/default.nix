{ lib, writeShellScriptBin, docker }:

writeShellScriptBin "mac-nix" ''
  #!/usr/bin/env bash
  # This script wraps Nix commands to run inside a Docker container for compatibility with macOS.

  # Ensure Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Docker does not seem to be running, please start Docker first."
    exit 1
  fi

  # Run the Nix command in the nixpkgs/nix-flakes Docker container
  docker run -it --rm \\
    -v "$PWD:/build" \\
    $(env | sed 's/^/-e /') \\
    nixpkgs/nix-flakes "\$@"
''

