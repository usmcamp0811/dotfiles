{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, python3Packages
, fetchgit
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;


  label-studio = python3Packages.buildPythonPackage rec {
    pname = "label-studio";
    version = "1.9.1.post0";
    src = fetchgit {
      url = "https://github.com/HumanSignal/label-studio.git";
      rev = "521e5ca88e1143ee132239574806224e852689f9";
      sha256 = "1w6lzpkb25wwl1kdlxp3plrw7313jlfkk3cgn7cn9z69996dp5rq";
    };

    buildInputs = [];
    propagatedBuildInputs = [];
    doCheck = false;

    meta = {
      description = "Label Studio";
      license = lib.licenses.asl20;
    };
  };

  new-meta = with lib; {
    description = "Label Studio is a multi-type data labeling and annotation tool with standardized output format";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta label-studio
