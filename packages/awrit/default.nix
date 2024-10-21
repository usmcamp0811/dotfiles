{ pkgs, stdenv, lib, cmake, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "awrit";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "Chase";
    repo = "awrit";
    rev = "main";
    sha256 = "sha256-9OlH5qx1zxulwQmNoaX3eLtw1MFEsTh/DUaK43xqDSM=";
  };

  buildInputs = [ cmake ];

  # Patch the CMakeLists.txt file before building
  patchPhase = ''
    substituteInPlace CMakeLists.txt \
      --replace "GetCEFFileInfoForVesion" "GetCEFFileInfoForVersion"
    substituteInPlace CMakeLists.txt \
      --replace 'file(READ "''${CMAKE_BINARY_DIR}/index.json" INDEX_CONTENT)' \
                'file(READ "''${CMAKE_BINARY_DIR}/index.json" INDEX_CONTENT)\nif(INDEX_CONTENT STREQUAL "")\n  message(FATAL_ERROR "Failed to download index.json or it is empty.")\nendif()'
    substituteInPlace CMakeLists.txt \
      --replace 'string(JSON SHA GET ''${CEF_FILE_INFO} "''${CEF_VERSIONS}" ''${VERSION_IDX} files ''${FILE_IDX} sha1)' \
                'string(JSON SHA GET "''${FILES}" ''${FILE_IDX} sha1)'
    substituteInPlace CMakeLists.txt \
      --replace 'string(JSON NAME GET ''${CEF_FILE_INFO} "''${CEF_VERSIONS}" ''${VERSION_IDX} files ''${FILE_IDX} name)' \
                'string(JSON NAME GET "''${FILES}" ''${FILE_IDX} name)'
    substituteInPlace CMakeLists.txt \
      --replace 'FetchContent_Declare(cef_src' \
                'if(DEFINED CEF_FILE_NAME AND DEFINED CEF_FILE_SHA)\n  FetchContent_Declare(cef_src'
    substituteInPlace CMakeLists.txt \
      --replace 'SOURCE_SUBDIR cmake)' \
                'SOURCE_SUBDIR cmake)\nelse()\n  message(FATAL_ERROR "CEF file name or SHA is not defined. Cannot proceed with download.")\nendif()'
  '';

  # Standard build phases
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  installPhase = ''
    mkdir -p $out/bin
    cp awrit $out/bin/
  '';

  meta = with lib; {
    description = "Awrit project with patched CMakeLists.txt";
    license = licenses.bsd3;
    maintainers = with maintainers; [ your_github_username ];
  };
}
