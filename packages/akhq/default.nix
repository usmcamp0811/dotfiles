{
  lib,
  writeText,
  writeShellApplication,
  substituteAll,
  gum,
  inputs,
  pkgs,
  hosts ? {},
  ...
}: 
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "akhq";
  version = "0.24.0";
  jar = pkgs.fetchurl {
    url = "https://github.com/tchiotludo/akhq/releases/download/${version}/akhq-${version}-all.jar";
    sha256 = "sha256-yNc+u/vk1gz29KbnKdHXPvWVqmywuhsxAZkE+8kkkWk=";  # Replace with actual SHA256 of the jar file
  };

  akhq = pkgs.stdenv.mkDerivation rec {
    inherit pname;
    inherit version;

    src = ./.;
    buildInputs = [ pkgs.jdk17 ];

    installPhase = ''
      mkdir -p $out/bin $out/share/java
      cp ${jar} $out/share/java/akhq.jar
      cat > $out/bin/akhq <<EOF
      #!${pkgs.stdenv.shell}
      exec ${pkgs.jdk17}/bin/java -Dmicronaut.config.files=\$1 -jar $out/share/java/akhq.jar
      EOF
      chmod +x $out/bin/akhq
    '';
  };

  new-meta = with lib; {
    description = "A Kafka Headquarters";
    homepage = "https://github.com/tchiotludo/akhq";
    license = pkgs.lib.licenses.mit;
    maintainers = with maintainers; [mattcamp];
  };
in
override-meta new-meta akhq
