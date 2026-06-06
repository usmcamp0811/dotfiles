{
  inputs,
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli.aliases.root;

  # Generated file content for custom aliases
  aliasesFile =
    pkgs.writeText "aliases.shrc"
    "${convertAlias cfg.aliases}";

  default-aliases = pkgs.writeText "default-aliases.shrc" (convertAlias {
    ".." = "cd ..";
    "cd.." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";
    "~" = "cd ~"; # `cd` is probably faster to type though
    "--" = "cd -";
    mv = "mv -v";
    rm = "rm -i -v";
    cp = "cp -v";
    la = "${pkgs.lsd}/bin/lsd -laF --group-dirs first";
    ls = "${pkgs.lsd}/bin/lsd --tree --depth 3";
    df = "df -h";
    chmox = "chmod -x";
    status = "sudo systemctl status";
    start = "sudo systemctl start";
    stop = "sudo systemctl stop";
    restart = "sudo systemctl restart";
    disable = "sudo systemctl disable";
    enable = "sudo systemctl enable";
    deploy-sys = "${pkgs.deploy-rs}/bin/deploy --hostname $1 --skip-checks .#$1";
    flake-update = ''${pkgs.nix}/bin/nix flake update --option access-tokens "github.com=$GITHUB_TOKEN"'';
    kill = ''
      [ $# -eq 0 ] && echo 'You need to specify whom to kill.' && return
            /usr/bin/kill $@'';
    update-sys = "sh -c 'nixos-rebuild switch --flake /config/#$(hostname) |& nom'";
    get-approle = ''
      local role_id=$(sudo cat /var/lib/vault/$(hostname)/role-id)
      local secret_id=$(sudo cat /var/lib/vault/$(hostname)/secret-id)
      export VAULT_TOKEN=$(${pkgs.vault-bin}/bin/vault write -field=token auth/approle/login role_id="$role_id" secret_id="$secret_id")
    '';
    zfs-unlock = ''
      HOST=$1
      ssh root@$HOST "zpool import -a -N && zfs load-key -a"
    '';
    # TODO: Add some function to get all virtual IPs and add them to allowed_hosts
    ssh = ''
      local target_host="$1"
      local known_hosts_file="''${HOME}/.ssh/known_hosts"
      local allowed_hosts=("10.8.0.69" "10.8.0.42" "10.8.0.55")

      if [[ " ''${allowed_hosts[*]} " =~ " ''${target_host} " ]]; then
          echo "Handling special case for $target_host..."
          # Remove the existing key if it exists
          ssh-keygen -R "$target_host" > /dev/null 2>&1
          echo "Removed existing key for $target_host (if it existed)."

          # Add the new host key to known_hosts
          ssh-keyscan -H "$target_host" >> "$known_hosts_file" 2>/dev/null
          echo "Added new key for $target_host to known_hosts."
      fi

      # Pass all arguments to the regular ssh command
      command ssh "$@"
    '';
    hyprmon = ''
      # Easily adjust monitors over ssh
      # Usage:
      #   hyprmon monitors
      #   hyprmon keyword monitor "DP-2, disable"
      #   hyprmon keyword monitor "DP-2, 1920x1080@60, auto, 1"

      local sig
      sig=$(hyprctl instances | awk '/^instance /{gsub(":","",$2); print $2; exit}')
      hyprctl --instance "$sig" "$@"
    '';
  });
in {
  options.fmf.cli.aliases = with types; {
    root = {
      enable = mkEnableOption "Shell aliases for root user";
      aliases = mkOption {
        type = attrsOf str;
        default = {};
        description = "A set of custom command aliases to add for root user.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Source the alias files in the shell configuration for root user only
    programs.zsh.interactiveShellInit = lib.mkAfter ''
      # Only apply aliases for root user
      if [ "$USER" = "root" ]; then
        source ${default-aliases}
        source ${aliasesFile}
      fi
    '';
  };
}
