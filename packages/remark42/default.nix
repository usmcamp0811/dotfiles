{ stdenv, lib, fetchurl, }:

stdenv.mkDerivation rec {
  name = "remark42-${version}";
  version = "1.13.1";

  src = fetchurl {
    url =
      "https://github.com/umputun/remark42/releases/download/v1.13.0/remark42.linux-amd64.tar.gz";
    sha256 = "sha256-VE5Kp7NyIwblsM/sruxIUDwhPnElV3v2XHPJyCV9jg8=";
  };

  unpackPhase = ''
    tar xvf $src
  '';

  installPhase = ''
    install -m755 -D remark42.linux-amd64 $out/bin/remark42
  '';

  meta = with lib; {
    homepage = "https://remark42.com";
    description = "A comment engine";
    platforms = platforms.linux;
    maintainers = with maintainers; [ seqiz ];
  };
}
