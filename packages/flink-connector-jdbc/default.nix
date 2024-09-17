{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  kafka-jar = "flink-connector-jdbc_2.12";
  jar-version = "1.13.6";

  kafkaPlugin = pkgs.fetchurl {
    url =
      "https://repo.maven.apache.org/maven2/org/apache/flink/${kafka-jar}/${jar-version}/${kafka-jar}-${jar-version}.jar";
    sha256 = "sha256-uuRbj0towaLvRjtIvw/QF2Wl0gzcCLMGTJb0P/ngdz4=";
  };
in kafkaPlugin
