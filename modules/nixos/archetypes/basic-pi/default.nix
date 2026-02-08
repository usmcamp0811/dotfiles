{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.basic-pi;
in {
  options.fmf.archetypes.basic-pi = with types; {
    enable = mkBoolOpt false "Whether or not to enable the basic-pi archetype.";
  };

  config = mkIf cfg.enable {
    fmf = {
      # suites = {common = enabled;};
      system = {
        passwds = enabled;
      };
      services = {
        ntp = enabled;
        docker = enabled;
        tang = enabled;
        openssh = {
          authorizedKeys = [
            "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          ];
        };
      };
    };
  };
}
