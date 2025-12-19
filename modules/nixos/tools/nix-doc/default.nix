{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.nix-doc;
in {
  options.fmf.tools.nix-doc = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix-doc.";
  };

  config = mkIf cfg.enable {
    nix.extraOptions = ''
      plugin-files = ${pkgs.nix-doc}/lib/libnix_doc_plugin.so
    '';

    environment.systemPackages = with pkgs; [nix-doc];
  };
}
