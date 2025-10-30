{ config, pkgs, lib, ... }:
with lib;
with lib.namespace-change-me;
let
  cfg = config.namespace-change-me.nix;
  substituters-submodule = types.submodule ({ ... }: {
    options = with types; {
      key =
        mkOpt (nullOr str) null "The trusted public key for this substituter.";
    };
  });
in {
  options.namespace-change-me.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt package pkgs.nixVersions.stable "Which nix package to use.";
    additional-authorized-users =
      mkOpt (listOf str) [ ] "List of authorized users";

    default-substituter = {
      url = mkOpt str "https://cache.nixos.org" "The url for the substituter.";
      key = mkOpt str
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "The trusted public key for the substituter.";
    };

    extra-substituters = mkOpt (attrsOf substituters-submodule) { }
      "Extra substituters to configure.";
  };

  config.namespace-change-me = mkIf cfg.enable { nix = cfg; };
}
