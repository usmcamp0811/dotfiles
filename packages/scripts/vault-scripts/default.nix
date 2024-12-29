{ lib, writeShellScriptBin, pkgs, hosts ? { } }:
with lib;
with lib.campground;
let
  inherit (lib) mapAttrsToList;
  name = "vault-scripts";
  version = "0.1.0";

  # Import individual scripts
  checkVaultPath = import ./scripts/check-vault-paths.nix { inherit pkgs; };
  initVaultScript = import ./scripts/init-vault.nix { inherit pkgs; };
  systemChecker = import ./scripts/system-vault-checker.nix {
    inherit pkgs checkVaultPath lib;
  };
  getVaultPaths =
    import ./scripts/get-vault-paths.nix { inherit pkgs checkVaultPath; };
  newAppRole = import ./scripts/create-approle.nix { inherit pkgs; };
  saveAppRoleSecrets =
    import ./scripts/save-approle-secrets.nix { inherit pkgs; };
  README = ./README.md;
  vault-crawler = import ./scripts/vault-crawler.nix { inherit pkgs; };
  raft-recovery = import ./scripts/raft-recovery.nix { inherit pkgs; };
  delete-rejoin-raft =
    import ./scripts/delete-rejoin-raft.nix { inherit pkgs; };

  # Create a helper script for running commands
  runScripts = writeShellScriptBin "vault-scripts" ''
    ${pkgs.bat}/bin/bat --plain ${README}
  '';

  # Derivation for vault-scripts
  vaultScripts = pkgs.stdenv.mkDerivation {
    inherit version;
    pname = name;

    src = ./.;

    installPhase = ''
      mkdir -p $out/bin
      cp ${newAppRole}/bin/create-approle $out/bin
      cp ${getVaultPaths}/bin/get-vault-paths $out/bin
      cp ${saveAppRoleSecrets}/bin/save-approle-secrets $out/bin
      cp ${initVaultScript}/bin/init-vault $out/bin
      cp ${vault-crawler}/bin/vault-crawler $out/bin
      cp ${raft-recovery}/bin/raft-recovery $out/bin
      cp ${delete-rejoin-raft}/bin/delete-rejoin-raft $out/bin
      cp ${runScripts}/bin/vault-scripts $out/bin
      cp ${README} $out/README.md
    '';

    meta = with lib; {
      mainProgram = "vault-scripts";
      description =
        "A collection of Vault-related scripts for managing AppRoles and checking paths.";
      homepage = "https://gitlab.com/usmcamp0811/dotfiles.git";
      license = licenses.mit;
    };
  };
in
vaultScripts // {
  create-approle = newAppRole;
  get-vault-paths = getVaultPaths;
  save-approle-secrets = saveAppRoleSecrets;
  init-vault = initVaultScript;
  vault-crawler = vault-crawler;
  system-check = systemChecker;
  raft-recovery = raft-recovery;
  delete-rejoin-raft = delete-rejoin-raft;
  vault = pkgs.vault-bin;
}
