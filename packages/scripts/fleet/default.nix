{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "fleet";
  runtimeInputs = with pkgs; [bash nix jq git findutils diffutils coreutils gnused gnugrep];
  # The derivation rules live in lib/fleet (shared with downstream drift checks). They are read by
  # `nix eval` at run time, so they have to be a store file; interpolating the path copies it there.
  text = builtins.replaceStrings ["@LIB@"] ["${../../../lib/fleet/default.nix}"] (builtins.readFile ./fleet.sh);
  meta = with lib; {
    description = "Derive leases, DNS records and port forwards from the fmf.host records of a flake's hosts";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "fleet";
  };
}
