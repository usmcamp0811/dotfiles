{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.server;
in
{
  options.fmf.archetypes.server = with types; {
    enable = mkBoolOpt false "Whether or not to enable the server archetype.";
    k8s = mkBoolOpt false "Is this a K8s Node?";
    keyfile-url =
      mkOpt str "http://10.8.0.1/zfs-keyfile" "URL to get zfs keyfile";
    hostId = mkOpt str "" "ZFS Host ID";
    isLeader = mkBoolOpt false "Whether or not k0s leader";
  };

  config = mkIf cfg.enable {
    fmf = {
      suites = {
        common = enabled;
        observability = enabled;
      };
      system = {
        zfs = {
          enable = true;
          hostId = cfg.hostId;
          keyfile-url = cfg.keyfile-url;
        };
        passwds = enabled;
      };
      services = {
        netbird.client = enabled;
        ntp = enabled;
        docker = enabled;
        ldap-client = enabled;
        tang = enabled;
        openssh = {
          authorizedKeys = [
            "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
          ];
        };
      };
    };
  };
}
