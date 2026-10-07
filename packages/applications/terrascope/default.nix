{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication rec {
  pname = "terrascope";
  version = "0.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "a-shygun";
    repo = "Terrascope";
    rev = "v${version}";
    hash = "sha256-1Wdg/4eCv+h6XLO2mm8zHTUxbwGa+ZTyZWBEDtWkBEg=";
  };

  build-system = with python3Packages; [hatchling];
  dependencies = with python3Packages; [numpy pillow pyyaml pyshp];
  pythonImportsCheck = ["terrascope"];

  meta = {
    description = "A braille-rendered terminal world map with live data layers";
    homepage = "https://github.com/a-shygun/Terrascope";
    license = lib.licenses.mit;
    mainProgram = "terrascope";
    platforms = lib.platforms.unix;
  };
}
