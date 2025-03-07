{ pkgs, ... }:
{ }
# pkgs.runCommand "mkPyFlinkDerivation" { src = ./.; } ''
#   mkdir -p $out
#   ${pkgs.campground.example-flink-job.test}/bin/run-tests > $out/result.txt
# ''
