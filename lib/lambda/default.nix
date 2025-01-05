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
  # @param pythonSrc - The source path of the Python file containing the Lambda handler.
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
    , system
    , pkgs
    , pythonSrc
    , pythonEnv ? pkgs.python3.withPackages (ps: [ ps.awslambdaric ])
    }:
    let
      appSource = pkgs.runCommand "buildApp" { inherit pythonSrc; } ''
        mkdir -p $out
        cp $pythonSrc $out/$(basename $pythonSrc)
      '';

      handler = getLambdaHandler pythonSrc;

      awsLambdaRie = pkgs.writeShellScript "aws-lambda-rie" ''
        ${pkgs.aws-lambda-rie}/bin/aws-lambda-rie \
          --runtime-interface-emulator-address 0.0.0.0:''${LAMBDA_PORT:-9001} \
          ${pythonEnv}/bin/python -m awslambdaric ${handler}
      '';

      devServer = pkgs.writeShellScript "devserver" ''
        ls *.py flake.nix | ${pkgs.entr}/bin/entr -r ${awsLambdaRie}
      '';

    in
    pkgs.dockerTools.buildLayeredImage
      {
        inherit name;
        config = {
          EntryPoint = [ "${pythonEnv}/bin/python" "-m" "awslambdaric" ];

          WorkingDir = "${appSource}";

          Cmd = [ "app.handler" ];
        };
      } // {
      inherit devServer appSource;
    };
}
