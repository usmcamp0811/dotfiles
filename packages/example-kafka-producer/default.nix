{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  producer = ./producer.py;
  python-env = pkgs.python311.buildEnv.override {
    extraLibs = [ pkgs.python311Packages.kafka-python ];
    ignoreCollisions = true;
  };

in writeShellApplication {
  name = "example-kafka-producer";
  meta = { mainProgram = "example-kafka-producer"; };
  text = ''
    HOST="10.8.0.72" # Default host
    PORT=9092      # Default port
    TOPIC="example-topic"
    MESSAGE=""

    # Parse command-line arguments for --host, --port, and --message
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --host) HOST="$2"; shift ;;
            --port) PORT="$2"; shift ;;
            --message) MESSAGE="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done

    # Execute the producer script with or without message
    if [[ -n "$MESSAGE" ]]; then
      ${python-env}/bin/python3 ${producer} "$HOST" "$PORT" "$TOPIC" "$MESSAGE"
      exit 0
    else
      ${python-env}/bin/python3 ${producer} "$HOST" "$PORT" "$TOPIC"
    fi
  '';
}
