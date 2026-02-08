{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.laptop;
in
{
  options.fmf.archetypes.laptop = with types; {
    enable = mkBoolOpt false "Whether or not to enable the laptop archetype.";
  };

  config = mkIf cfg.enable {
    services.logind.lidSwitch = "ignore";

    services.tlp = {
      enable = true;
      settings = {
        TLP_DEFAULT_MODE = "BAT";
        TLP_PERSISTENT_DEFAULT = 1;
      };
    };

    fmf = {
      suites = {
        common = enabled;
        desktop = enabled;
        development = enabled;
      };
      services = {
        ntp = enabled;
        docker = enabled;
        ldap-client = enabled;
        openssh = {
          authorizedKeys = [
            "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          ];
        };
      };
      system = {
        wifi = {
          enable = true;
          networks = {
            SkyNet = { ssid = "SkyNet"; };
            SkyNet5 = { ssid = "SkyNet5"; };
            SkyNet6 = { ssid = "SkyNet2.0"; };
          };
        };
      };
    };
  };
}
