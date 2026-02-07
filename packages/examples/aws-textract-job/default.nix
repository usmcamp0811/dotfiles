{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.fmf;
mkAWSLambdaPythonImage {
  inherit pkgs system;
  name = "pdf_ocr";
  handler = "pdf_ocr.lambda_handler";
  src = ./.;
  pythonEnv = pkgs.python312.withPackages
    (ps: [ ps.awslambdaric ps.requests ps.jsons ps.boto3 ]);
}
