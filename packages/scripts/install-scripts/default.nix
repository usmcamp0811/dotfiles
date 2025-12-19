{ lib, writeShellScriptBin, pkgs, hosts ? { } }:
with lib;
with lib.fmf;
let
  name = "install-scripts";
  version = "0.1.0";

  # Import individual scripts
  partitionScript = import ./scripts/partition.nix { inherit pkgs; };
  btrfsScript = import ./scripts/format-btrfs.nix { inherit pkgs; };
  zfsScript = import ./scripts/format-zfs.nix { inherit pkgs; };
  README = ./README.md;

  zfs-setup = writeShellScriptBin "zfs-setup" ''
    ${partitionScript}/bin/partition
    ${zfsScript}/bin/format-zfs
  '';

  btrfs-setup = writeShellScriptBin "btrfs-setup" ''
    ${partitionScript}/bin/partition
    ${btrfsScript}/bin/format-btrfs
  '';

  # Create a helper script for running commands
  runScripts = writeShellScriptBin "install-scripts" ''
    ${pkgs.bat}/bin/bat --plain ${README}
  '';

  installScripts = pkgs.stdenv.mkDerivation {
    inherit version;
    pname = name;

    src = ./.;

    installPhase = ''
      mkdir -p $out/bin
      cp ${partitionScript}/bin/partition $out/bin
      cp ${runScripts}/bin/install-scripts $out/bin
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
installScripts // {
  partition = partitionScript;
  format-zfs = zfsScript;
  format-btrfs = btrfsScript;
  setup-zfs = zfs-setup;
  setup-btrfs = btrfs-setup;
}
