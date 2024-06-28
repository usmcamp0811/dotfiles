{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  julia-env = pkgs.julia.withPackages [ "IJulia" "CSV" "DataFrames" ];
  python = pkgs.python311.withPackages
    (pythonPackages: with pythonPackages; [ jupyter qtconsole ]);
  startJupyterWithJulia = writeShellApplication {
    name = "start-jupyter-with-julia";
    runtimeInputs = [ python julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      JULIA_VERSION="myjulia-$(julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel("myjulia")'
      jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  pname = "julia";
  version = pkgs.julia.version;

  buildInputs = [ python julia-env ];

  installPhase = ''
    mkdir $out/bin
    cp ${julia-env}/bin/julia $out/bin/julia
  '';
  mainProgram = "julia";

  passthru = { jj = startJupyterWithJulia; };
}
