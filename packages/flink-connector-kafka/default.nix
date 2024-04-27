{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  kafka-jar = "flink-sql-connector-kafka";
  jar-version = "3.0.2-1.18";
  kafkaPlugin = pkgs.fetchurl {
    url =
      "https://repo.maven.apache.org/maven2/org/apache/flink/${kafka-jar}/${jar-version}/${kafka-jar}-${jar-version}.jar";
    sha256 = "sha256-b9NgGdoshvz4VFj0N2F6vKWjQnwjAoJg99OQ6tidnVI=";
  };
in kafkaPlugin
