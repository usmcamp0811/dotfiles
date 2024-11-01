{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.qdrant;
in {
  options.campground.services.qdrant = with types; {
    enable = mkBoolOpt false "Enable Qdrant.";

    settings = mkOption {
      type = types.yaml;
      default = {
        storage = {
          storage_path = "/var/lib/qdrant/storage";
          snapshots_path = "/var/lib/qdrant/snapshots";
        };
        hsnw_index = { on_disk = true; };
        service = {
          host = "127.0.0.1";
          http_port = 6333;
          grpc_port = 6334;
        };
        telemetry_disabled = true;
      };
      description = ''
        Configuration for Qdrant. Refer to https://github.com/qdrant/qdrant/blob/master/config/config.yaml for details on supported values.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.qdrant = {
      enable = true;
      settings = cfg.settings;
    };
  };
}
