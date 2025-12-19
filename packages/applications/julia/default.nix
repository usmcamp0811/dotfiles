{ lib, pkgs, inputs, ... }:
with lib;
with lib.fmf;
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;
  julia-env = pkgs.julia.withPackages.override
    {
      extraLibs = [
        pkgs.stdenv.cc.cc
        pkgs.libxcrypt
        pkgs.libxcrypt-legacy
        pkgs.openssl
        pkgs.cyrus_sasl
      ];
      setDefaultDepot = true;
    } [
    "FileIO"
    "JLD2"
    "DataFrames"
    "MLJ"
    "PyCall"
    "IJulia"
    "CSV"
    "LanguageServer"
    "GLM"
    "StatsPlots"
    "StatsModels"

    # "Plotly"
    "Plots"
  ];

  startJupyterWithJulia = createJuliaConsole "julia-console"
    "${pkgs.jupyter-all}/bin/jupyter console"
    {
      pkgs = pkgs;
      juliaEnv = julia-env;
      kernelName = "campground";
    };
  startQtJupyterWithJulia = createJuliaConsole "julia-qtconsole"
    "${pkgs.jupyter-all}/bin/jupyter qtconsole"
    {
      pkgs = pkgs;
      juliaEnv = julia-env;
      kernelName = "campground";
    };
  juliaInFHS = (pkgs.scientific-fhs.override (oldAttrs: {
    commandScript = "julia";
    juliaEnv = pkgs.fmf.julia;
  }));
  startJupyterWithJuliaFHS = (pkgs.scientific-fhs.override (oldAttrs: {
    commandScript = "julia-console";
    juliaEnv = pkgs.fmf.julia;
  }));
  startQtJupyterWithJuliaFHS = (pkgs.scientific-fhs.override (oldAttrs: {
    commandScript = "julia-qtconsole";
    juliaEnv = pkgs.fmf.julia;
  }));

  container = pkgs.dockerTools.buildLayeredImage {
    name = "julia";
    tag = "latest";
    contents = [ juliaInFHS ];
    config = { Entrypoint = [ "julia" ]; };
  };
in
pkgs.stdenv.mkDerivation rec {
  pname = "julia";
  version = pkgs.julia.version;
  src = ./.;

  buildInputs = [ pkgs.jupyter-all julia-env pkgs.openssl ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r ${julia-env}/bin/julia $out/bin/julia
    cp -r ${startJupyterWithJulia}/bin/* $out/bin/
    cp -r ${startQtJupyterWithJulia}/bin/* $out/bin/
  '';
  mainProgram = "julia";

  passthru = {
    jupyter-qtconsole = startQtJupyterWithJulia;
    jupyter-console = startJupyterWithJulia;
    fhs = juliaInFHS // {
      jupyter-qtconsole = startQtJupyterWithJuliaFHS;
      jupyter-console = startJupyterWithJuliaFHS;
      container = container;
    };
  };
}
