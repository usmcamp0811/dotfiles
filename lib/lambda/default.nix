{ lib, ... }:
with lib; rec {
  getLambdaHandler = src:
    builtins.replaceStrings [ ".py" ] [ "" ] (builtins.baseNameOf src);

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
