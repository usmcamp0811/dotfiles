{ lib, pkgs, config, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.apps.ai-jail;
in {
  options.fmf.apps.ai-jail = with types; {
    enable = mkBoolOpt false
      "Whether to install ai-jail, a bubblewrap/Landlock/seccomp sandbox for running AI coding agents.";
    package = mkOpt package pkgs.ai-jail "The ai-jail package to install.";
  };

  config = mkIf cfg.enable {
    # The packaged binary is wrapped with BWRAP_BIN set to a store bubblewrap,
    # so no separate bubblewrap install is required.
    environment.systemPackages = [ cfg.package ];
  };
}
