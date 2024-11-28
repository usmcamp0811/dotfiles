{ inputs, options, config, pkgs, lib, ... }:
with lib;
with lib.campground;
let
  # Function to convert alias definitions into shell functions
  convertAlias = aliasAttrs:
    builtins.concatStringsSep "\n" (mapAttrsToList
      (name: value: ''
        ${name}() {
          ${value}
        }
      '')
      aliasAttrs);

  # Generated file content for aliases
  aliasesContent = convertAlias config.campground.cli.aliases;

in
{
  options.campground.cli.aliases = with types;
    mkOption {
      type = attrsOf str;
      default = { };
      description = "A set of command aliases to set.";
    };

  config = {
    # Source the alias file in the shell configuration
    programs.zsh.initExtra = lib.mkAfter ''
      source ${aliasesFilePath}
    '';
  };
}
