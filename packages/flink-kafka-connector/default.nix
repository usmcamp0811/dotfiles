{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "flink-kafka-connector";
  version = "1.18.0";

  flink-kafka-connector = pkgs.stdenv.mkDerivation rec {
    inherit pname;
    inherit version;

    src = pkgs.fetchurl {
      url =
        "https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka_${version}/flink-connector-kafka_${version}.jar";
      sha256 = ""; # Replace with the actual SHA256 of the JAR file
    };

    installPhase = ''
      mkdir -p $out/lib
      cp $src $out/lib/
    '';

  };

  new-meta = with lib; {
    description = "Apache Flink Kafka Connector";
    homepage = "https://flink.apache.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in override-meta new-meta flink-kafka-connector
