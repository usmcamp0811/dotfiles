{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, system
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  inherit system;
  pname = "julia";

  description = "Julia wrapped for Nix";

  version = "1.9.2";

  julia = inputs.julia2nix.lib.${system}.julia-wrapped {
    # package = inputs.julia2nix.packages.${system}.julia_19-bin;
    package = inputs.julia2nix.packages.${system}.julia_19-bin;
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
    src = ./.;  
    package = julia;
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };

  new-meta = with lib; {
    description = "Julia Wrapped for Nix";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

in
override-meta new-meta julia
