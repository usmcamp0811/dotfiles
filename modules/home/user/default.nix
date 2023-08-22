{ lib, config, pkgs, osConfig ? { }, ... }:


let
  inherit (lib) types mkIf mkDefault mkMerge;
  inherit (lib.campground) mkOpt;

  cfg = config.campground.user;

  is-linux = pkgs.stdenv.isLinux;
  is-darwin = pkgs.stdenv.isDarwin;

  default-key =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler";

  home-directory =
    if cfg.name == null then
      null
    else if is-darwin then
      "/Users/${cfg.name}"
    else
      "/home/${cfg.name}";
in
{
  options.campground.user = {
    enable = mkOpt types.bool false "Whether to configure the user account.";
    name = mkOpt (types.nullOr types.str) config.snowfallorg.user.name "The user account.";

    fullName = mkOpt types.str "Matt Camp" "The full name of the user.";
    email = mkOpt types.str "matt@aicampground.com" "The email of the user.";

    home = mkOpt (types.nullOr types.str) home-directory "The user's home directory.";

    authorizedKeys = mkOpt types.str default-key "The public key to apply.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "campground.user.name must be set";
        }
        {
          assertion = cfg.home != null;
          message = "campground.user.home must be set";
        }
      ];

      home = {
        username = mkDefault cfg.name;
        homeDirectory = mkDefault cfg.home;
      };
    }
  ]);
}
