{ pkgs, stdenv, lib, cmake, fetchFromGitHub }:
let
  CEF_VERSION = "120.1.10+g3ce3184+chromium-120.0.6099.129";
  CEF_PLATFORM =
    if stdenv.isDarwin then
      "macosx64"
    else if stdenv.isLinux then
      "linux64"
    else
      "windows64";

  cefFile = pkgs.fetchurl {
    url =
      "https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION}_${CEF_PLATFORM}.tar.bz2";
    sha256 = "sha256-o7A080YgJu0CcyRJ2hgjVOOaPa+Wm6EDJS7TcR6rd/g=";
  };

  googletestFile = pkgs.fetchurl {
    url =
      "https://github.com/google/googletest/archive/refs/tags/v1.13.0.tar.gz";
    sha256 = "sha256-rX/boR6gEcHZJbMonPSvLGajUuGNTHJkOS/q116Rk2M=";
  };

in
pkgs.stdenv.mkDerivation rec {
  pname = "awrit";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "Chase";
    repo = "awrit";
    rev = "main";
    sha256 = "sha256-9OlH5qx1zxulwQmNoaX3eLtw1MFEsTh/DUaK43xqDSM=";
  };

  nativeBuildInputs = [ pkgs.cmake ];

  buildInputs = [ pkgs.libstdcxx5 ];

  unpackPhase = ''
    runHook preUnpack
    cp -r ${src}/* .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # Use the downloaded CEF and GTest files.
    cp -r ${cefFile} ./cef
    cp -r ${googletestFile} ./googletest
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description =
      "Package awrit without CMakeLists.txt dependencies, fetched via Nix";
    license = licenses.bsd3;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
