{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, system
, nuenv
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  inherit system;
  pname = "mlflow";

  description = "MLFlow hack job";

  version = "2.3.2";
  pkgs.nuenv.mkDerivation {
    name = "hello";
    src = ./.;
    inherit system;
    # This script is Nushell, not Bash
    packages = with pkgs; [ hello ];
    build = ''
      hello --greeting $"($env.MESSAGE)" | save hello.txt
      let out = $"($env.out)/share"
      mkdir $out
      cp hello.txt $out
    '';
    MESSAGE = "My custom Nuenv derivation!";
  };
  new-meta = with lib; {
    description = description;
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta mlflow
