{ lib, ... }:
with lib; rec {
  #
  # Extracts the Lambda handler name from the given Python source file path.
  #
  # @param src - The path to the Python source file.
  # @return The base name of the Python source file, without the ".py" extension.
  getLambdaHandler = src:
    builtins.replaceStrings [ ".py" ] [ "" ] (builtins.baseNameOf src);

  #
  # Creates an AWS Lambda-compatible Docker image for Python, incorporating a Nix-based
  # Python environment and runtime tools.
  #
  # @param name - (Optional) The name of the Docker image. Defaults to "aws-lambda-with-nix".
  # @param system - The target system for the build, e.g., "x86_64-linux".
  # @param pkgs - The Nixpkgs set used to define dependencies.
  # @param src - The source path of the Python code containing the Lambda Function.
  # @param pythonEnv - (Optional) A Python environment with required packages.
  #                    Defaults to an environment with the `awslambdaric` package.
  #
  # @return A Docker image with:
  #   - The Python source file as the application code.
  #   - A configured Python environment for AWS Lambda.
  #   - Development scripts (`aws-lambda-rie` for local testing, and a `devserver` for hot reload).
  #   - Pass-through attributes for `devServer` and `appSource`, allowing direct access to
  #     these components for further customization or integration.
  mkAWSLambdaPythonImage =
    { name ? "aws-lambda-with-nix"
    , handler
    , system
    , pkgs
    , src ? ./.
    , pythonEnv ? pkgs.python3.withPackages (ps: [ ps.awslambdaric ])
    }:
    let
      appSource = pkgs.runCommand "buildApp" { inherit src; } ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      awsLambdaRie = pkgs.writeShellScriptBin "aws-lambda-rie" ''
        set -e
        usage() {
          echo "Usage: aws-lambda-rie [-d DIRECTORY] [-p PORT] [-h HOST] lambda_file.handler"
          echo "  -d DIRECTORY   Path to the Lambda function directory (default: ${src})"
          echo "  -p PORT        Port for the runtime interface emulator (default: 9001)"
          echo "  -h HOST        Host for the runtime interface emulator (default: 0.0.0.0)"
          echo "  -f FUNCTION    Lambda Function to Run (default: ${handler})"
          exit 1
        }

        # Default values
        LAMBDA_DIR="${src}"
        LAMBDA_PORT=9001
        LAMBDA_HOST="0.0.0.0"
        LAMBDA_HANDLER="${handler}"

        # Parse arguments
        while [ $# -gt 0 ]; do
          case "$1" in
            -d)
              if [ -n "$2" ]; then
                LAMBDA_DIR="$2"
                shift 2
              else
                usage
              fi
              ;;
            -p)
              if [ -n "$2" ]; then
                LAMBDA_PORT="$2"
                shift 2
              else
                usage
              fi
              ;;
            -h)
              if [ -n "$2" ]; then
                LAMBDA_HOST="$2"
                shift 2
              else
                usage
              fi
              ;;
            -f)
              if [ -n "$2" ]; then
                LAMBDA_HANDLER="$2"
                shift 2
              else
                usage
              fi
              ;;
            -*)
              usage
              ;;
            *)
              break
              ;;
          esac
        done

        LAMBDA_DIR=$(realpath "$LAMBDA_DIR")
        if [ ! -d "$LAMBDA_DIR" ]; then
            echo "Error: Directory $LAMBDA_DIR does not exist."
            exit 1
        fi
        # Run the AWS Lambda RIE
        cd "$LAMBDA_DIR" || (echo "Directory $LAMBDA_DIR does not exist" && exit 1)

        printf "Running AWS Lambda Server: SRC: $LAMBDA_DIR \tFUNCTION: $LAMBDA_HANDLER\n"
        if [ -z "$LAMBDA_HANDLER" ]; then 
          echo "No lambda handler provided. Using default handler: lambda_function.handler"
          ${pkgs.aws-lambda-rie}/bin/aws-lambda-rie \
            --runtime-interface-emulator-address "''${LAMBDA_HOST}:''${LAMBDA_PORT}" \
            ${pythonEnv}/bin/python -m awslambdaric lambda_function.handler
        else
          ${pkgs.aws-lambda-rie}/bin/aws-lambda-rie \
            --runtime-interface-emulator-address "''${LAMBDA_HOST}:''${LAMBDA_PORT}" \
            ${pythonEnv}/bin/python -m awslambdaric "$LAMBDA_HANDLER"
        fi
      '';

      devServer = pkgs.writeShellScriptBin "devserver" ''
        set -e
        usage() {
          echo "Usage: devserver [-d DIRECTORY] [-p PORT] [-h HOST] lambda_code.handler"
          echo "  -d DIRECTORY   Path to the Lambda function directory (default: ${src})"
          echo "  -p PORT        Port for the runtime interface emulator (default: 9001)"
          echo "  -h HOST        Host for the runtime interface emulator (default: 0.0.0.0)"
          echo "  -f FUNCTION    Lambda Function to Run (default: ${handler})"
          exit 1
        }

        # Default values
        LAMBDA_DIR="${src}"
        LAMBDA_PORT=9001
        LAMBDA_HOST="0.0.0.0"
        LAMBDA_HANDLER="${handler}"

        # Parse arguments
        while [ $# -gt 0 ]; do
          case "$1" in
            -d)
              if [ -n "$2" ]; then
                LAMBDA_DIR="$2"
                shift 2
              else
                usage
              fi
              ;;
            -p)
              if [ -n "$2" ]; then
                LAMBDA_PORT="$2"
                shift 2
              else
                usage
              fi
              ;;
            -h)
              if [ -n "$2" ]; then
                LAMBDA_HOST="$2"
                shift 2
              else
                usage
              fi
              ;;
            -f)
              if [ -n "$2" ]; then
                LAMBDA_HANDLER="$2"
                shift 2
              else
                usage
              fi
              ;;
            -*)
              usage
              ;;
            *)
              break
              ;;
          esac
        done

        LAMBDA_HANDLER="$1"

        LAMBDA_DIR=$(realpath "$LAMBDA_DIR")
        if [ ! -d "$LAMBDA_DIR" ]; then
            echo "Error: Directory $LAMBDA_DIR does not exist."
            exit 1
        fi

        # Navigate to the specified directory
        if ! cd "$LAMBDA_DIR"; then
          echo "Error: Directory $LAMBDA_DIR does not exist."
          exit 1
        fi

        FILES=$(find "$LAMBDA_DIR" -maxdepth 1 \( -name "*.py" -o -name "flake.nix" \))
        if [ -z "$FILES" ]; then
          echo "Error: No files found to monitor in $LAMBDA_DIR."
          exit 1
        fi

        # Monitor the directory and restart aws-lambda-rie on changes
        if [ -z "$LAMBDA_HANDLER" ]; then
          echo "$FILES" | ${pkgs.entr}/bin/entr -r ${awsLambdaRie}/bin/aws-lambda-rie \
            -d "$LAMBDA_DIR" -p "$LAMBDA_PORT" -h "$LAMBDA_HOST"
        else
          echo "$FILES" | ${pkgs.entr}/bin/entr -r ${awsLambdaRie}/bin/aws-lambda-rie \
            -d "$LAMBDA_DIR" -p "$LAMBDA_PORT" -h "$LAMBDA_HOST" "$LAMBDA_HANDLER"
        fi
      '';

    in
    pkgs.dockerTools.buildLayeredImage
      {
        inherit name;
        config = {
          EntryPoint = [ "${pythonEnv}/bin/python" "-m" "awslambdaric" ];

          WorkingDir = "${appSource}";

          Cmd = [ handler ];
        };
      } // {
      inherit devServer appSource awsLambdaRie;
    };

  # NOTE: The registry url has to be passed in and can not be done here becaue of context things wiht terranix
  pushLambdaToAWS =
    { pkgs, config, lambdaImg, registryName, oci-program ? pkgs.docker }:
    let
      awsRegion = config.provider.aws.region;
      buildPushScript = pkgs.writeShellScriptBin "build-push" ''
        echo "Logging in to ${registryName}"
        # Authenticate Docker with AWS ECR
        ${pkgs.awscli}/bin/aws ecr get-login-password --region ${awsRegion} | \
        ${pkgs.docker}/bin/docker login --username AWS --password-stdin "$1"

        # Tag and push the Docker image
        ${
          lib.campground.pushDockerImage {
            inherit pkgs;
            dockerImage = lambdaImg;
          }
        }/bin/push-docker-image --image-name="$1" --tag="${lambdaImg.imageName}"
      '';
    in
    buildPushScript;
}
