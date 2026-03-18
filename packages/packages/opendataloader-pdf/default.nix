{ lib, pkgs, jdk17, ... }:

let
  pname = "opendataloader-pdf";
  version = "2.0.0";

  # Create Python environment with opendataloader-pdf from PyPI
  python-env = pkgs.python3.withPackages (ps:
    [
      # The package is available on PyPI and includes the JAR files
      (ps.buildPythonPackage rec {
        pname = "opendataloader-pdf";
        version = "2.0.0";
        format = "wheel";

        src = pkgs.fetchurl {
          url =
            "https://files.pythonhosted.org/packages/3d/5f/c97ee55c1c78b96cc65172106123a6dd27e87d8d062c4e3134dc400c3531/opendataloader_pdf-2.0.0-py3-none-any.whl";
          hash = "sha256-GAk/qHowiavboUBDwYf4XGpK9IxFl3EN4y2Q6VZmMT4=";
        };

        # No build dependencies needed for wheel
        doCheck = false;

        meta = with lib; {
          description = "PDF Parser for AI-ready data";
          homepage =
            "https://github.com/opendataloader-project/opendataloader-pdf";
          license = licenses.asl20;
        };
      })
    ]);

in pkgs.writeShellApplication {
  name = "opendataloader-pdf";
  runtimeInputs = [ jdk17 ];
  text = ''
    export JAVA_HOME="${jdk17}"
    exec ${python-env}/bin/python -m opendataloader_pdf "$@"
  '';

  meta = with lib; {
    description =
      "PDF Parser for AI-ready data. Automate PDF accessibility. Open-source.";
    longDescription = ''
      OpenDataLoader PDF is a PDF parser designed for AI data extraction and accessibility.
      It extracts Markdown, JSON (with bounding boxes), and HTML from PDFs.
      Features include:
      - #1 in benchmarks (0.90 overall accuracy)
      - Built-in OCR for scanned PDFs (80+ languages)
      - Complex table extraction
      - LaTeX formula extraction
      - AI-generated chart/image descriptions
    '';
    homepage = "https://github.com/opendataloader-project/opendataloader-pdf";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "opendataloader-pdf";
    platforms = platforms.unix;
  };
}
