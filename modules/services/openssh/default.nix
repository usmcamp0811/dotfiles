{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.openssh;

  user = config.users.users.${config.campground.user.name};
  user-id = builtins.toString user.uid;

  default-key =
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJ4v/zUQ40k9NwUZN8atDyHRv/dVzAGp/MNYuDCEQ/DPQ+3x3peJvytnHPxg1/f90WUb/D2PJoo2J/W95EpdZTPFcWEJLVlECpc5ym5irBcrCtLwWwu1didHOZ80051WXEL5rIhpoaAXb0rVgEHOVV8coSpZDvQ/Z2n+YtlqK58Kz9xFI+odCfaHrjwLHWm+AzZ1c3xGtYflVcD5GuYcx2LgA8xc3yypPDSK6U926So0wrEzxpg2SZnlb8nrDS9iD5ZR91AU8rEeTRWcx5uBaJTgT0cYRMflauAjONBspy/QMGQ7lUXAJVkrzRdelUtWitNgtMsnDd+u3Htc8Q/bvd+DLCeNdcESO9UH5PfaVEF8tKL0bQNa90fiEKl2sU845azE6l9BQCqmkiLKaGs8UQ3xkUQDENTjzDzaaG2sH/ackFoo4q90Ky8NUto/qNh1Wvp474nSZ5/StvaZ3238mw1ltJaF5iI0V/RPGACrn7PcBYkyohmwLD4AZGrx+IV+E= mcamp@butler
";

  other-hosts = lib.filterAttrs
    (key: host:
      key != name && (host.config.campground.user.name or null) != null)
    ((inputs.self.nixosConfigurations or { }) // (inputs.self.darwinConfigurations or { }));

  other-hosts-config = lib.concatMapStringsSep
    "\n"
    (name:
      let
        remote = other-hosts.${name};
        remote-user-name = remote.config.campground.user.name;
        remote-user-id = builtins.toString remote.config.users.users.${remote-user-name}.uid;

        forward-gpg = optionalString (config.programs.gnupg.agent.enable && remote.config.programs.gnupg.agent.enable)
          ''
            RemoteForward /run/user/${remote-user-id}/gnupg/S.gpg-agent /run/user/${user-id}/gnupg/S.gpg-agent.extra
            RemoteForward /run/user/${remote-user-id}/gnupg/S.gpg-agent.ssh /run/user/${user-id}/gnupg/S.gpg-agent.ssh
          '';

      in
      ''
        Host ${name}
          User ${remote-user-name}
          ForwardAgent yes
          Port ${builtins.toString cfg.port}
          ${forward-gpg}
      ''
    )
    (builtins.attrNames other-hosts);
in
{
  options.campground.services.openssh = with types; {
    enable = mkBoolOpt false "Whether or not to configure OpenSSH support.";
    authorizedKeys =
      mkOpt (listOf str) [ default-key ] "The public keys to apply.";
    port = mkOpt port 2222 "The port to listen on (in addition to 22).";
    manage-other-hosts = mkOpt bool true "Whether or not to add other host configurations to SSH config.";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;

      settings = {
        PermitRootLogin = if format == "install-iso" then "yes" else "no";
        PasswordAuthentication = false;
      };

      extraConfig = ''
        StreamLocalBindUnlink yes
      '';

      ports = [
        22
        cfg.port
      ];
    };

    programs.ssh.extraConfig = ''
      Host *
        HostKeyAlgorithms +ssh-rsa

      ${optionalString cfg.manage-other-hosts other-hosts-config}
    '';

    campground.user.extraOptions.openssh.authorizedKeys.keys =
      cfg.authorizedKeys;

    campground.home.extraOptions = {
      programs.zsh.shellAliases = foldl
        (aliases: system:
          aliases // {
            "ssh-${system}" = "ssh ${system} -t tmux a";
          })
        { }
        (builtins.attrNames other-hosts);
    };
  };
}
