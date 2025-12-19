{ mkShell, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  julia-env = pkgs.julia.withPackages.override {
    extraLibs =
      [ pkgs.libxcrypt pkgs.libxcrypt-legacy pkgs.openssl pkgs.cyrus_sasl ];
  } [ "FileIO" "DataFrames" "PyCall" "IJulia" "CSV" "RDKafka" ];

  startJupyterWithJulia = createJuliaConsole "julia-console"
    "${pkgs.jupyter-all}/bin/jupyter console" {
      pkgs = pkgs;
      juliaEnv = julia-env;
      kernelName = "kafka-play";
    };
  startQtJupyterWithJulia = createJuliaConsole "julia-qtconsole"
    "${pkgs.jupyter-all}/bin/jupyter qtconsole" {
      pkgs = pkgs;
      juliaEnv = julia-env;
      kernelName = "kafka-play";
    };

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
    startJupyterWithJulia
    startQtJupyterWithJulia
  ];

  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
  '';
}
