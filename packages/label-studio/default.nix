{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, fetchgit
, hosts ? { }
, ...
}:

inputs.dream2nix.url = "github:Dream2nix/dream2nix";  # replace with the actual source
let
  label-studio = { inputs, python, dream2nix, ...}: {
    imports = [
      inputs.dream2nix.modules
    ];
    
    name = "label-studio";
    version = "1.5.0";
    deps = {nixpkgs, ...}: {
      python = nixpkgs.python310;
    };
    
    buildPythonPackage = {
      pythonImportsCheck = [
        "label_studio"  # or whatever the python package name is
      ];
    };
    
    pip = {
      pypiSnapshotDate = "2023-10-20";
      requirementsList = ["label-studio==1.9.1"];
    };

    meta = with lib; {
      description = "Label Studio is a multi-type data labeling and annotation tool with standardized output format";
      license = licenses.asl20;
      maintainers = with maintainers; [ mattcamp ];
    };
  };
in
{
  packages.x86_64-linux.label-studio = label-studio;
}
