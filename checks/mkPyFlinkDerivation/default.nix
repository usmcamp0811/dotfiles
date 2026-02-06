{ pkgs, ... }:
{ }
# pkgs.runCommand "mkPyFlinkDerivation" { src = ./.; } ''
#   mkdir -p $out
#   ${pkgs.fmf.example-flink-job.test}/bin/run-tests > $out/result.txt
# ''
