{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "vault-access";
  runtimeInputs = with pkgs; [bash nix jq git findutils diffutils coreutils gnused gnugrep];
  # The derivation rules live in lib/vault-access (shared with downstream checks). It is read by
  # `nix eval` at run time, so it has to be a store file; interpolating the path copies it there.
  text = builtins.replaceStrings ["@LIB@"] ["${../../../lib/vault-access/default.nix}"] (builtins.readFile ./vault-access.sh);
  meta = with lib; {
    description = "Write the per-service Vault policies derived from vault-agent templates, and the host -> policies map";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "vault-access";
  };
}
