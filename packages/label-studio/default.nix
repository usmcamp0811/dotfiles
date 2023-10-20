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
  label-studio = { python, dream2nix, ...}:
  {
    imports = [
      dream2nix.modules.dream2nix.pip
    ];

    name = "label-studio";
    version = "1.9.1.post0";

    deps = {nixpkgs, ...}: {
      python = nixpkgs.python310;
    };

    name = name;
    version = version;

    buildPythonPackage = {
      pythonImportsCheck = [
        name
      ];
    };

    pip = {
      pypiSnapshotDate = "2023-10-20";
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
