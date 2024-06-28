{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  julia-env = pkgs.julia.withPackages
    (juliaPackages: with juliaPackages; [ IJulia DataFrames CSV ]);
  python = pkgs.python311.withPackages
    (pythonPackages: with pythonPackages; [ jupyter qtconsole ]);
  startJupyterWithJulia = writeShellApplication {
    name = "start-jupyter-with-julia";
    runtimeInputs = [ python julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      jupyter console --kernel julia-1.7
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  pname = "my-jupyter-env";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ python julia-env startJupyterWithJulia ];

  passthru = {
    jupyter = ''
      ${startJupyterWithJulia}/bin/start-jupyter-with-julia
    '';
  };
}
