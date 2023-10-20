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

  # sqlparse = python3Packages.buildPythonPackage rec {
  #   pname = "sqlparse";
  #   version = "0.4.4";
  #
  #   src = fetchgit {
  #     url = "https://github.com/andialbrecht/sqlparse.git";
  #     rev = "0.4.4";
  #     sha256 = "18avmnn3zmhcxqj0m1bdcwv5fql4zab2di25jqqqbsq2b71a8vnm";
  #   };
  #   format = "pyproject";
  #   nativeBuildInputs = [ pkgs.python310Packages.flit-core ];
  #
  #   meta = with lib; {
  #     description = "A non-validating SQL parser module for Python";
  #     license = licenses.bsd3;  # Update the license accordingly
  #     maintainers = with maintainers; [ /* your name or handle here */ ];
  #   };
  # };
  boto3 = python3Packages.buildPythonPackage rec {
    pname = "boto3";
    version = "1.16.28";

    src = fetchgit {
      url = "https://github.com/boto/boto3.git";
      rev = "1.16.28";
      sha256 = "07dscqwir8n2qqviwgmwk94pi6diy0a6jbgj8b8580k5qcqd4l0n";
    };
    format = "pyproject";
    nativeBuildInputs = [ pkgs.python310Packages.setuptools ];

    meta = with lib; {
      description = "AWS SDK for Python";
      license = lib.licenses.asl20;  # Update the license accordingly
      maintainers = with maintainers; [ /* your name or handle here */ ];
    };
  };

  django-debug-toolbar = python3Packages.buildPythonPackage rec {
    pname = "django-debug-toolbar";
    version = "3.2.1";

    src = fetchgit {
      url = "https://github.com/jazzband/django-debug-toolbar.git";
      rev = "3.2.1";
      sha256 = "1m1j2sx7q0blma0miswj3c8hrfi5q4y5cq2b816v8gagy89xgc57";  # Fill in the correct sha256
    };
    propagatedBuildInputs = [
     pkgs.python310Packages.django
     boto3

    ];

    doCheck = false;

    meta = {
      description = "A configurable set of panels displaying various debug information about the current request/response.";
      license = lib.licenses.bsd3;
    };
  };


  label-studio = python3Packages.buildPythonPackage rec {
    pname = "label-studio";
    version = "1.9.1.post0";
    src = fetchgit {
      url = "https://github.com/HumanSignal/label-studio.git";
      rev = "521e5ca88e1143ee132239574806224e852689f9";
      sha256 = "1w6lzpkb25wwl1kdlxp3plrw7313jlfkk3cgn7cn9z69996dp5rq";
    };

    buildInputs = [];
    propagatedBuildInputs = [
     # sqlparse
     django-debug-toolbar 
    ];
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
