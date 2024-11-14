{ options, config, lib, host ? "", format ? "", inputs ? { }, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.openssh;

  user = config.users.users.${config.campground.user.name};
  user-id = builtins.toString user.uid;

  # @TODO(jakehamilton): This is a hold-over from an earlier Snowfall Lib version which used
  # the specialArg `name` to provide the host name.
  name = host;

  default-key =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler";

  other-hosts = lib.filterAttrs
    (key: host:
      key != name && (host.config.campground.user.name or null) != null)
    ((inputs.self.nixosConfigurations or { })
      // (inputs.self.darwinConfigurations or { }));

  other-hosts-config = lib.concatMapStringsSep "\n"
    (name:
      let
        remote = other-hosts.${name};
        remote-user-name = remote.config.campground.user.name;
        remote-user-id =
          builtins.toString remote.config.users.users.${remote-user-name}.uid;

        forward-gpg = optionalString
          (config.programs.gnupg.agent.enable
            && remote.config.programs.gnupg.agent.enable) ''
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
      '')
    (builtins.attrNames other-hosts);
in
{
  options.campground.services.openssh = with types; {
    enable = mkBoolOpt false "Whether or not to configure OpenSSH support.";
    authorizedKeys =
      mkOpt (listOf str) [ default-key ] "The public keys to apply.";
    port = mkOpt port 2222 "The port to listen on (in addition to 22).";
    manage-other-hosts = mkOpt bool true
      "Whether or not to add other host configurations to SSH config.";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = mkForce
          (if format == "install-iso" then "yes" else "prohibit-password");
        # PermitRootLogin =
        #   if format == "install-iso" then "yes" else "without-password";
        # PasswordAuthentication = true;
        # X11Forwarding = true;
        # TODO: flip back to false when all is good
      };

      extraConfig = ''
        StreamLocalBindUnlink yes
      '';

      ports = [ 22 cfg.port ];
    };

    programs.ssh.forwardX11 = true;
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
