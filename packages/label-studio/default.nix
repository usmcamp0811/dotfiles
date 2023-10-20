{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, dream2nix
, fetchgit
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  label-studio = let 
    name = "label-studio";
    version = "1.9.1.post0";
  in
  {
    imports = [
      dream2nix.modules.dream2nix.pip
    ];

    deps = {nixpkgs, ...}: {
      python = nixpkgs.python39;
    };

    name = name;
    version = version;

    buildPythonPackage = {
      pythonImportsCheck = [
        name
      ];
    };

    pip = {
      pypiSnapshotDate = "2023-01-01";
      requirementsList = ["${name}==${version}"];
    };
  };

  new-meta = with lib; {
    description = "Label Studio is a multi-type data labeling and annotation tool with standardized output format";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta label-studio
