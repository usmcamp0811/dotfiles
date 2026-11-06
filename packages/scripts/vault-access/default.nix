{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "vault-access";
  runtimeInputs = with pkgs; [bash nix jq git findutils diffutils coreutils gnused];
  # extract.nix is read by `nix eval` at run time; interpolating the path copies it to the store.
  text = builtins.replaceStrings ["@EXTRACT@"] ["${./extract.nix}"] (builtins.readFile ./vault-access.sh);
  meta = with lib; {
    description = "Derive one least-privilege Vault policy per service from vault-agent templates, and map hosts to them";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "vault-access";
  };
}
