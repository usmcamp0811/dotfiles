{ lib
, writeText
, writeShellApplication
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "A wrapper around redfin's unofficial API. Anything on the redfin site can be accessed through this module without screen scraping.";
    homepage = "https://github.com/reteps/redfin";
    license = licenses.mit; # Update the license if necessary
    maintainers = with maintainers; [ matt-camp ];
  };

  redfin = pkgs.nix-unstable.python311Packages.buildPythonPackage {
    pname = "redfin";
    version = "0.1.1";

    src = pkgs.fetchPypi {
      pname = "redfin";
      version = "0.1.1";
      sha256 = "sha256-C8lmhvpcBDzIhh5A5y23DU4gKcPWrhEWEEnsF+Pn7EI=";
    };
    doCheck = false;

    meta = {
      description = "redfin";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ mattcamp ];
    };
  };
in
override-meta new-meta redfin
