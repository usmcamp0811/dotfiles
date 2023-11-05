{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, system
, julia2nix
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  inherit system;
  pname = "julia-wrapped";

  description = "Julia wrapped for Nix";

  version = "1.0.0";

  julia-wrapped = inputs.julia2nix.lib.${system}.julia-wrapped {
    package = julia2nix.packages.${system}.julia_19-bin;
    enable = {
      # only x86_64-linux is supported
      GR = true;
      python = 
        pkgs.python3.buildEnv.override
        {
          extraLibs = with pkgs.python3Packages; [xlrd matplotlib plotly pyqt5 jupyter ];
          # ignoreCollisions = true;
        };
    };
  };
  project = pkgs.stdenv.mkDerivation {
    name = "campground-julia";
    src = ./.;  # Copy the entire project directory into the Nix store
    package = julia-wrapped;
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };

  new-meta = with lib; {
    description = "A Simple Flask App";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

in
override-meta new-meta julia-wrapped
