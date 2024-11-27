{ lib, writeText, writeShellScriptBin, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.cyclops) override-meta;
  pname = "vault-scripts";

  description = "A package for all of the Vault things...";

  version = "0.1.0";
  checkVaultPath = import ./checkVaultPath.nix { inherit pkgs; };
  getVaultPaths = import ./getVaultPaths.nix { inherit pkgs checkVaultPath; };
  # devshell-python = import ./python-env.nix  { inherit pkgs; };
  new-approle = import ./new-approle.nix { inherit pkgs; };
  save-approle-secrets =
    import ./save-approle.nix { inherit pkgs new-approle; };

  vault-scripts = pkgs.stdenv.mkDerivation {
    name = "vault-report";
    src = ./.; # Copy the entire project directory into the Nix store
    installPhase = ''
      mkdir -p $out/bin
      cp -r ./* $out/

      cp ${new-approle}/bin/create-approle $out/bin
      cp ${getVaultPaths}/bin/get-vault-paths $out/bin
      cp ${save-approle-secrets}/bin/save-approle-secrets $out/bin

      echo "#!/usr/bin/env sh" > $out/bin/vault-report
      # echo "$''${devshell-python}/bin/python3 $src/vault-table.py" >> $out/bin/vault-report
      chmod +x $out/bin/vault-report

      echo "#!/usr/bin/env sh" > $out/bin/check-vault-paths
      echo "$out/bin/get-vault-paths | $out/bin/vault-report" >> $out/bin/check-vault-paths
      chmod +x $out/bin/check-vault-paths
    '';
  };

  run-script = writeShellScriptBin "run-script" ''
    #!/usr/bin/env sh
    if [ $# -lt 1 ]; then
      echo "Usage: $0 <script> [args]"
      exit 1
    fi
    SCRIPT=$1
    shift
    echo "Running: $SCRIPT"
    sh ${vault-scripts}/bin/$SCRIPT "$@"
  '';
in run-script // {
  new-approle = new-approle;
  get-vault-paths = getVaultPaths;
  save-approle-secrets = save-approle-secrets;
  vault = pkgs.vault-bin;
}
