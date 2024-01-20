{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, pkgs
, system
, hosts ? { }
, ...
}:

let
  inherit system;

  nuenv-hello = pkgs.nuenv.mkDerivation {
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
in
nuenv-hello
