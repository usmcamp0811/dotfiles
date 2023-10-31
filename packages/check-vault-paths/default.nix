{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "vault-scripts";

  description = "A package for all of the Vault things...";

  version = "0.1.0";
  checkVaultPath = import ./checkVaultPath.nix { inherit pkgs; };
  getVaultPaths  = import ./getVaultPaths.nix  { inherit pkgs checkVaultPath; };
  devshell-python = import ./python-env.nix  { inherit pkgs; };
  new-approle = import ./new-approle.nix  { inherit pkgs; };

  thisProject = pkgs.stdenv.mkDerivation {
    name = "CampgroundDotfiles";
    src = ./.;  # Copy the entire project directory into the Nix store
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };
  vault-report = pkgs.stdenv.mkDerivation {
    name = "vault-report";
    src = ./.;  # Copy the entire project directory into the Nix store
    installPhase = ''
      mkdir -p $out/bin
      cp -r ./* $out/
      cp ${new-approle}/bin/create-approle $out/bin
      cp ${getVaultPaths}/bin/get-vault-paths $out/bin
      echo "#!/usr/bin/env sh" > $out/bin/vault-report
      echo "${devshell-python}/bin/python3 ${thisProject}/vault-table.py" >> $out/bin/vault-report
      chmod +x $out/bin/vault-report
      echo "#!/usr/bin/env sh" > $out/bin/check-vault-paths
      echo "$out/bin/get-vault-paths | $out/bin/vault-report" >> $out/bin/check-vault-paths
      chmod +x $out/bin/check-vault-paths
    '';
};
  new-meta = with lib; {
    description = "A thing to check Vault to see if all the paths in the Flake are good";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta vault-report
