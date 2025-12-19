{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.python;
  python =
    pkgs.python3.withPackages
    (ps: [ps.bpython ps.numpy ps.pandas]);
in {
  options.fmf.tools.python = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Python.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [
        # libstdcxx5
        zlib
        gcc
        glib
        poetry
      ]
      ++ [python];

    home.sessionVariables = {
      PYTHON_KEYRING_BACKEND = "keyring.backends.null.Keyring";
      # LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib:${pkgs.zlib}/lib";
    };
  };
}
