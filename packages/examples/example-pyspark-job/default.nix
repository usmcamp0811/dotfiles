{ pkgs, lib, ... }:
with lib;
with lib.fmf;

let
  python-env = pkgs.python3.withPackages (ps: [ ps.pyspark ]);

  example-pyspark-job = ./job.py;

in pkgs.writeShellApplication {
  name = "example-pyspark-job";
  text = ''
    if [ "$#" -lt 3 ]; then
      echo "Usage: example-pyspark-job --master <master_url> --input <input_path> --output <output_path>"
      echo "Arguments:"
      echo "  --master <master_url>   URL of the Spark master (e.g., spark://reckless:7070)"
      echo "  --input <input_path>    Path to the input file (e.g., hdfs://reckless:9000/path/to/input.txt)"
      echo "  --output <output_path>  Path to the output directory (e.g., hdfs://reckless:9000/path/to/output)"
      exit 1
    fi

    MASTER=""
    INPUT=""
    OUTPUT=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --master)
          MASTER="$2"
          shift 2
          ;;
        --input)
          INPUT="$2"
          shift 2
          ;;
        --output)
          OUTPUT="$2"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1"
          exit 1
          ;;
      esac
    done

    if [ -z "$MASTER" ] || [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
      echo "Error: Missing required arguments."
      echo "Run example-pyspark-job without arguments for usage."
      exit 1
    fi

    ${pkgs.spark}/bin/spark-submit --master "$MASTER" ${example-pyspark-job} --input "$INPUT" --output "$OUTPUT"
  '';
}
