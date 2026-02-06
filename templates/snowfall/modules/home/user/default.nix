{ lib, inputs, config, pkgs, ... }:
let
  inherit (lib) types mkIf mkDefault mkMerge;
  inherit (lib.namespace-change-me) mkOpt;

  cfg = config.namespace-change-me.user;
  cfg-user = config.namespace-change-me.user;
  is-darwin = pkgs.stdenv.isDarwin;

  default-key =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler";

  home-directory = if cfg.name == null then
    null
  else if is-darwin then
    "/Users/${cfg.name}"
  else
    "/home/${cfg.name}";
in {
  options.namespace-change-me.user = {
    enable = mkOpt types.bool false "Whether to configure the user account.";
    name = mkOpt (types.nullOr types.str) config.snowfallorg.user.name
      "The user account.";

    uid = mkOpt types.int 1000 "UID of the user";
    fullName = mkOpt types.str "Matt Camp" "The full name of the user.";
    email =
      mkOpt types.str "matt@ainamespace-change-me.com" "The email of the user.";

    home = mkOpt (types.nullOr types.str) home-directory
      "The user's home directory.";

    authorizedKeys = mkOpt types.str default-key "The public key to apply.";
  };

  config = mkIf cfg.enable (mkMerge [{
    assertions = [
      {
        assertion = cfg.name != null;
        message = "namespace-change-me.user.name must be set";
      }
      {
        assertion = cfg.home != null;
        message = "namespace-change-me.user.home must be set";
      }
    ];

    home = {
      username = mkDefault cfg.name;
      homeDirectory = mkDefault cfg.home;
    };
  }]);
}
