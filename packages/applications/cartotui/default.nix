{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchurl,
}: let
  pmtiles = python3Packages.buildPythonPackage rec {
    pname = "pmtiles";
    version = "3.4.1";
    format = "setuptools";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/21/69/5c2e4eb58aaf6303aebbaad3e6d7394b96d28f94af5bc16a6540d815bb09/pmtiles-3.4.1.tar.gz";
      hash = "sha256-SNbY8xfn7B9BUKcVscIgd3+J8MEGGHSmAiJVoIWYNu4=";
    };
    doCheck = false;
    meta = {
      description = "Library and utilities for reading and writing PMTiles archives";
      homepage = "https://github.com/protomaps/pmtiles";
      license = lib.licenses.bsd3;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "cartotui";
  version = "0.14.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "SAMS0N1TE";
    repo = "CartoTUI";
    rev = "v${version}";
    hash = "sha256-Au3OGEDSe4IQq1wxYstnTQCZ/yqA5hjUuXnJ5YZ2Kiw=";
  };

  build-system = with python3Packages; [setuptools wheel];
  dependencies = with python3Packages; [
    prompt-toolkit
    requests
    pmtiles
    pyserial
    numpy
    pillow
  ];
  pythonImportsCheck = ["cartotui"];

  meta = {
    description = "Interactive terminal map viewer with vector and raster tile rendering";
    homepage = "https://github.com/SAMS0N1TE/CartoTUI";
    license = lib.licenses.gpl3Plus;
    mainProgram = "cartotui";
    platforms = lib.platforms.unix;
  };
}
