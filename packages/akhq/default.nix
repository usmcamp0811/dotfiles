{ stdenv, fetchFromGitHub, jre, gradle }:

stdenv.mkDerivation rec {
  pname = "akhq";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "tchiotludo";
    repo = "akhq";
    rev = "v${version}";
    sha256 = "<sha256>";
  };

  buildInputs = [ jre gradle ];

  buildPhase = ''
    ./gradlew build
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp build/libs/akhq*.jar $out/lib/
    # Also, consider copying other necessary files, like configuration templates.
  '';

  meta = {
    homepage = "https://github.com/tchiotludo/akhq";
    description = "A Kafka HQ tool";
    license = stdenv.lib.licenses.mit;
  };
}
