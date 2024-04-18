{
  lib,
  writeText,
  writeShellApplication,
  buildPythonPackage, 
  fetchFromGitHub,
  substituteAll,
  inputs,
  pkgs,
  hosts ? {},
  ...
}: let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "Karapace - a Kafka Schema Registry and REST Proxy";
    homepage = "https://github.com/Aiven-Open/karapace";
    license = licenses.mit;  # Update the license if necessary
    maintainers = with maintainers; [matt-camp];
  };

  pname = "karapace";
  version = "3.12.0"; 

  karapace = buildPythonPackage rec {
    inherit pname;
    inherit version;

    src = fetchFromGitHub {
      owner = "Aiven-Open";
      repo = "karapace";
      rev = version;
      sha256 = "0000000000000000000000000000000000000000000000000000";  # Placeholder hash
    };

    # propagatedBuildInputs = [ 
    #   # Add Python dependencies here, if they are not handled by setup.py
    # ];

    meta = with lib; {
      description = "Karapace - a Kafka Schema Registry and REST Proxy";
      homepage = "https://github.com/Aiven-Open/karapace";
      license = licenses.mit;  # Update the license if necessary
      maintainers = with maintainers; [ ];  # Add maintainers here
    };
  };

in
  override-meta new-meta karapace
