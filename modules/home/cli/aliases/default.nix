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
  aliasesFile = pkgs.writeText "aliases.shrc"
    "${convertAlias config.campground.cli.aliases}";

  default-aliases = pkgs.writeText "default-aliases.shrc" (convertAlias {
    ".." = "cd ..";
    "cd.." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";
    "~" = "cd ~"; # `cd` is probably faster to type though
    "--" = "cd -";
    "mv" = "mv -v";
    "rm" = "rm -i -v";
    "cp" = "cp -v";
    chmox = "chmod -x";
    status = "sudo systemctl status";
    start = "sudo systemctl start";
    stop = "sudo systemctl stop";
    restart = "sudo systemctl restart";
    disable = "sudo systemctl disable";
    enable = "sudo systemctl enable";
  });
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
      source ${default-aliases}
      source ${aliasesFile}
    '';
  };
}
