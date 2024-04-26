{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  pname = "flink-sql-connector-kafka";
  version = "3.0.2-1.18";
  kafkaPlugin = pkgs.fetchurl {
    url =
      "https://repo.maven.apache.org/maven2/org/apache/flink/${pname}/${version}/${pname}-${version}.jar";
    sha256 = "sha256-b9NgGdoshvz4VFj0N2F6vKWjQnwjAoJg99OQ6tidnVI=";
  };

  flink = pkgs.stdenv.mkDerivation rec {
    inherit pname version;
    src = pkgs.flink;

    installPhase = ''
      mkdir -p $out/opt/flink/opt
      mkdir -p $out/opt/flink/lib
      cp -r $src/* $out/
      ls -lah ${kafkaPlugin}
      cp ${kafkaPlugin} $out/opt/flink/lib/${pname}-${version}.jar
    '';
  };

  new-meta = with lib; {
    description = "A distributed stream processing framework";
    homepage = "https://flink.apache.org";
    downloadPage = "https://flink.apache.org/downloads.html";
    license = licenses.asl20;
    platforms = platforms.all;
    maintainers = with maintainers; [ mattcamp ];
  };
in override-meta new-meta flink
