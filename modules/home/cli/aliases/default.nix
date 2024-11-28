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
    dkill =
      "${pkgs.docker}/bin/docker stop $1 && ${pkgs.docker}/bin/docker rm $1";
    kill = ''
      [ $# -eq 0 ] && echo 'You need to specify whom to kill.' && return
            /usr/bin/kill $@'';
    update-user =
      "nix run /config/#homeConfigurations.''${USER}@ldap.activationPackage";
    update-sys =
      "sudo sh -c 'nixos-rebuild switch --flake /config/#$(hostname) |& nom'";
    get-approle = ''
      local role_id=$(sudo cat /var/lib/vault/$(hostname)/role-id)
      local secret_id=$(sudo cat /var/lib/vault/$(hostname)/secret-id)
      export VAULT_TOKEN=$(${pkgs.vault-bin}/bin/vault write -field=token auth/approle/login role_id="$role_id" secret_id="$secret_id")
    '';
    zfs-unlock = ''
      HOST=$1
      ssh root@$HOST "zpool import -a; zfs load-key -a && killall zfs"
    '';
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
