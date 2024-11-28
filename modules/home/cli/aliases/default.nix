{ inputs, options, config, pkgs, lib, ... }:
with lib;
with lib.campground;
let
  cfg-user = config.campground.user;
  is-darwin = pkgs.stdenv.isDarwin;

  home-directory =
    if cfg-user.name == null then
      null
    else if is-darwin then
      "/Users/${cfg-user.name}"
    else
      "/home/${cfg-user.name}";
in
{
  options.campground.cli.aliases = with types;
    mkOption {
      type = attrsOf (oneOf [ str path (listOf (either str path)) ]);
      apply = mapAttrs (_n: v:
        if isList v then
          concatMapStringsSep ":" (x: toString x) v
        else
          (toString v));
      default = { };
      description = "A set of environment variables to set.";
    };

  config = {
    # aliases are in a seperate file because we can't do shell functions in Nix
    home.file = { ".config/shell/aliases.shrc".source = aliases; };

    programs.zsh.initExtra = lib.mkAfter ''
      source ${aliases}
    '';
  };
}
