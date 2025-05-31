{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  producer = ./producer.py;
  python-env = pkgs.python311.buildEnv.override {
    extraLibs = [ pkgs.python311Packages.kafka-python ];
    ignoreCollisions = true;
  };

in
writeShellApplication {
  name = "example-kafka-producer";
  meta = { mainProgram = "example-kafka-producer"; };
  text = ''
    HOST="10.8.0.72" # Default host
    PORT=9092      # Default port
    TOPIC="example-topic"
    MESSAGE=""

    # Check if there are any arguments and the first argument is not a flag
    if [[ $# -gt 0 && "$1" != --* ]]; then
      MESSAGE="$1"
      shift
    fi

    # Parse command-line arguments for --host and --port
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --host) HOST="$2"; shift ;;
            --port) PORT="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done
    [[ -z "$MESSAGE" ]] && ${python-env}/bin/python3 ${producer} "$HOST" "$PORT" "$TOPIC"
    # Execute the producer script
    ${python-env}/bin/python3 ${producer} "$HOST" "$PORT" "$TOPIC" "$MESSAGE"
  '';
}
