{ lib
, writeText
, writeShellScriptBin
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
  name = "vault-scripts";
  version = "0.1.0";
  checkVaultPath = import ./scripts/check-vault-paths.nix { inherit pkgs; };
  getVaultPaths =
    import ./scripts/get-vault-paths.nix { inherit pkgs checkVaultPath; };
  new-approle = import ./scripts/new-approle.nix { inherit pkgs; };
  save-approle-secrets =
    import ./scripts/save-approle.nix { inherit pkgs new-approle; };

  vault-scripts = pkgs.stdenv.mkDerivation {
    inherit name version;
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      # Copy each script to $out/bin
      cp ${new-approle}/bin/create-approle $out/bin
      cp ${getVaultPaths}/bin/get-vault-paths $out/bin
      cp ${save-approle-secrets}/bin/save-approle-secrets $out/bin
      cp ${run-scripts}/bin/vault-scripts $out/bin
    '';
    meta = {
      mainProgram = "vault-scripts";
      description =
        "A collection of Vault-related scripts for managing AppRoles and checking paths.";
      homepage =
        "https://gitlab.com/usmcamp0811/dotfiles.git"; # Replace with your actual homepage
      license = lib.licenses.mit;
    };
  };

  run-scripts = writeShellScriptBin "vault-scripts" ''
      #!/usr/bin/env sh

      # Display help message
      show_help() {
        cat <<EOF
    Vault Scripts Usage Guide

    This package provides the following Vault-related scripts:

    1. create-approle:
       Description: Creates a new AppRole in HashiCorp Vault with an optional policy.
       Usage: create-approle <approle-name> [policy]
       Example: create-approle my-approle my-policy

    2. save-approle-secrets:
       Description: Retrieves and securely saves the role ID and secret ID for an AppRole.
       Usage: save-approle-secrets <approle-name>
       Example: save-approle-secrets my-approle

    3. check-vault-path:
       Description: Checks the existence of a specific path in HashiCorp Vault.
       Usage: check-vault-path <vault-path>
       Example: check-vault-path secret/data/my-secret

    How to use these scripts:
    - Each script is independently callable from your shell.
    - For more details about a script, use its respective --help option.

    EOF
      }

      # Show the help message when the script is invoked
      show_help
  '';
in
vault-scripts // {
  new-approle = new-approle;
  get-vault-paths = getVaultPaths;
  save-approle-secrets = save-approle-secrets;
}
