{ mkShell, pkgs, ... }:
let
  julia-env = (pkgs.julia.withPackages.override {
    precompile = false;
    extraLibs =
      [ pkgs.openssl pkgs.cyrus_sasl pkgs.zlib pkgs.rdkafka pkgs.apacheKafka ];
  }) [ "librdkafka_jll" ];
in mkShell {
  buildInputs = [
    julia-env
    pkgs.openssl
    pkgs.cyrus_sasl
    pkgs.zlib
    pkgs.rdkafka
    pkgs.glibc
    pkgs.cyrus_sasl
    pkgs.openssl
  ];

  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"

    # Additional setup can go here
  '';
}
