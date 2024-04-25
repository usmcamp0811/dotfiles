{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "flink-connector-kafka";
  version = "3.1.0";

  flink-connector-kafka = pkgs.stdenv.mkDerivation rec {
    inherit pname;
    inherit version;

    src = pkgs.fetchurl {
      url =
        "https://dlcdn.apache.org/flink/flink-connector-kafka-${version}/flink-connector-kafka-${version}-src.tgz";
      sha256 = "sha256-QXl2qPaatvOZEwNCc3THKYcBAuEu2W5FAEy5PBuTwAk=";
    };

    buildInputs = [ pkgs.gnutar ];

    installPhase = ''
      mkdir -p $out/lib
      tar -xzf $src -C $out
    '';

  };

  new-meta = with lib; {
    description = "Apache Flink Kafka Connector";
    homepage = "https://flink.apache.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in override-meta new-meta flink-connector-kafka
