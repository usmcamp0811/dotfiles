{ lib, inputs, config, pkgs, ... }:
let
  inherit (lib) types mkIf mkDefault mkMerge;
  inherit (lib.fmf) mkOpt;

  cfg = config.fmf.user;
  cfg-user = config.fmf.user;
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
  options.fmf.user = {
    enable = mkOpt types.bool false "Whether to configure the user account.";
    name = mkOpt (types.nullOr types.str) config.snowfallorg.user.name
      "The user account.";

    uid = mkOpt types.int 1000 "UID of the user";
    fullName = mkOpt types.str "Matt Camp" "The full name of the user.";
    email = mkOpt types.str "matt@aicampground.com" "The email of the user.";

    home = mkOpt (types.nullOr types.str) home-directory
      "The user's home directory.";

    authorizedKeys = mkOpt types.str default-key "The public key to apply.";
  };

  config = mkIf cfg.enable (mkMerge [{

    assertions = [
      {
        assertion = cfg.name != null;
        message = "fmf.user.name must be set";
      }
      {
        assertion = cfg.home != null;
        message = "fmf.user.home must be set";
      }
    ];

    home = {
      username = mkDefault cfg.name;
      homeDirectory = mkDefault cfg.home;
    };
    home.activation.sshKeys =
      inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -e "/var/lib/vault/users/${cfg-user.name}/id_ed25519" ]; then
          rm -rf /home/${cfg-user.name}/.ssh/id_ed25519
          cat /var/lib/vault/users/${cfg-user.name}/id_ed25519 > /home/${cfg-user.name}/.ssh/id_ed25519
          echo "" >> /home/${cfg-user.name}/.ssh/id_ed25519
          chmod 600 /home/${cfg-user.name}/.ssh/id_ed25519
          ${pkgs.openssh}/bin/ssh-keygen -y -f /home/${cfg-user.name}/.ssh/id_ed25519 > /home/${cfg-user.name}/.ssh/id_ed25519.pub
          chmod 644 /home/${cfg-user.name}/.ssh/id_ed25519.pub
          echo "Copied id_ed25519 successfully"
        else
          echo "id_ed25519 not found"
        fi
        if [ -e "/var/lib/vault/users/${cfg-user.name}/id_rsa" ]; then
          rm -rf /home/${cfg-user.name}/.ssh/id_rsa
          cat /var/lib/vault/users/${cfg-user.name}/id_rsa > /home/${cfg-user.name}/.ssh/id_rsa
          echo "" >> /home/${cfg-user.name}/.ssh/id_rsa
          ${pkgs.openssh}/bin/ssh-keygen -y -f /home/${cfg-user.name}/.ssh/id_rsa > /home/${cfg-user.name}/.ssh/id_rsa.pub
          chmod 600 /home/${cfg-user.name}/.ssh/id_rsa
          chmod 644 /home/${cfg-user.name}/.ssh/id_rsa.pub
          echo "Copied id_rsa successfully"
        else
          echo "id_rsa not found"
        fi
      '';
  }]);
}
