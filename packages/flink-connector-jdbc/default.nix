{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  kafka-jar = "flink-connector-jdbc";
  jar-version = "3.2.0-1.19";

  kafkaPlugin = pkgs.fetchurl {
    url =
      "https://repo.maven.apache.org/maven2/org/apache/flink/${kafka-jar}/${jar-version}/${kafka-jar}-${jar-version}.jar";
    sha256 = "sha256-KBNBkElPzvOYH1NgNc+nxPEqt4NCrBrKouDCPGNIQVg=";
  };
in kafkaPlugin
