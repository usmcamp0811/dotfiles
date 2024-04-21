{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  producer = ./produceer.py;
  python-env = python311.buildEnv.override {
    extraLibs = [ python311Packages.kafka-python ];
    ignoreCollisions = true;
  };

in writeShellApplication {
  name = "julia-kafka-producer";
  meta = { mainProgram = "kafka-publish"; };
  text = ''
    HOST="10.8.0.72" # Default host
    PORT=9092      # Default port
    TOPIC="example-topic"

    # Parse command-line arguments for --host and --port
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --host) HOST="$2"; shift ;;
            --port) PORT="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done

    ${python-env}/bin/python ${producer} $HOST $PORT $TOPIC"
  '';
}
