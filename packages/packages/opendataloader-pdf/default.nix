{ lib, pkgs, python3Packages, fetchFromGitHub, fetchurl, jdk17, makeWrapper
, unzip, ... }:

let
  pname = "opendataloader-pdf";
  version = "2.0.0";

  # Fetch the source repository
  src = fetchFromGitHub {
    owner = "opendataloader-project";
    repo = "opendataloader-pdf";
    rev = "v${version}";
    hash = "sha256-126z2rgkffshw4m4v9nhpxmfwy3zvdx9s980bbhp39lmdbvwhfpw";
  };

  # Fetch the pre-built CLI JAR from releases
  cliZip = fetchurl {
    url =
      "https://github.com/opendataloader-project/opendataloader-pdf/releases/download/v${version}/opendataloader-pdf-cli-${version}.zip";
    hash =
      "sha256-16fbb1b00c63ee5ac5d6bcfbd86f57f22b84971aac16e32158b95091f453cff7";
  };

  # Build the Python package
  pythonPackage = python3Packages.buildPythonPackage {
    inherit pname version src;

    format = "pyproject";

    # The package is in the python/opendataloader-pdf subdirectory
    sourceRoot = "${src.name}/python/opendataloader-pdf";

    nativeBuildInputs = with python3Packages;
      [ hatchling makeWrapper ] ++ [ unzip ];

    # Java is required at runtime
    buildInputs = [ jdk17 ];

    # Optional hybrid dependencies
    passthru.optional-dependencies = {
      hybrid = with python3Packages; [ fastapi uvicorn python-multipart ];
    };

    # Extract and include the pre-built JAR files
    preBuild = ''
      # Ensure the jar directory exists
      mkdir -p src/opendataloader_pdf/jar

      # Extract the CLI zip to get the JAR files
      unzip -q ${cliZip} -d /tmp/opendataloader-cli

      # Copy JAR files to the package
      cp -r /tmp/opendataloader-cli/opendataloader-pdf-cli-${version}/lib/*.jar src/opendataloader_pdf/jar/ || true

      # Clean up
      rm -rf /tmp/opendataloader-cli
    '';

    postInstall = ''
      # Ensure Java is available at runtime
      wrapProgram $out/bin/opendataloader-pdf \
        --prefix PATH : ${lib.makeBinPath [ jdk17 ]} \
        --set JAVA_HOME ${jdk17}

      # Wrap hybrid server if it exists
      if [ -f $out/bin/opendataloader-pdf-hybrid ]; then
        wrapProgram $out/bin/opendataloader-pdf-hybrid \
          --prefix PATH : ${lib.makeBinPath [ jdk17 ]} \
          --set JAVA_HOME ${jdk17}
      fi
    '';

    # Tests require network and complete setup
    doCheck = false;

    pythonImportsCheck = [ "opendataloader_pdf" ];

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
        - PDF accessibility auto-tagging (coming Q2 2026)
      '';
      homepage = "https://github.com/opendataloader-project/opendataloader-pdf";
      changelog =
        "https://github.com/opendataloader-project/opendataloader-pdf/blob/v${version}/CHANGELOG.md";
      license = licenses.asl20;
      maintainers = with maintainers; [ matt-camp ];
      mainProgram = "opendataloader-pdf";
      platforms = platforms.unix;
    };
  };

  # Create a variant with hybrid dependencies
  withHybrid = pythonPackage.overridePythonAttrs (old: {
    propagatedBuildInputs = (old.propagatedBuildInputs or [ ])
      ++ pythonPackage.passthru.optional-dependencies.hybrid;
  });

in pythonPackage // {
  passthru = (pythonPackage.passthru or { }) // { withHybrid = withHybrid; };
}
