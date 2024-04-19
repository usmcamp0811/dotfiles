{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.karapace;
in {
  options.campground.services.karapace = with types; {
    enable = mkBoolOpt false "Whether or not to enable Karapace.";
    config = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Karapace configuration settings as a Nix attribute set.";
    };
  };

  config = mkIf cfg.enable {
    users.users.apache-kafka = {
      isSystemUser = true;
      group = "apache-kafka";
      home = "/var/lib/apache-kafka";
      createHome = true;
    };

    users.groups.apache-kafka = {};

    systemd.services.karapace = {
      description = "Karapace Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # Pre-start script to convert Nix configuration to JSON
      serviceConfig = {
        ExecStartPre = lib.mkIf (cfg.config != {}) ''
          ${pkgs.jq}/bin/jq -n '${builtins.toJSON cfg.config}' > /var/lib/apache-kafka/config.json
        '';
        ExecStart = "${pkgs.campground.karapace}/bin/karapace /var/lib/apache-kafka/config.json";
        Restart = "always";
      };
    };

  };
}
