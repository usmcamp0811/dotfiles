{ lib, config, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.qdrant;
in {
  options.fmf.services.qdrant = with types; {
    enable = mkBoolOpt false "Enable Qdrant.";

    settings = mkOption {
      type =
        attrsOf (attrsOf str); # Update type to match nested attribute structure
      default = {
        storage = {
          storage_path = "/var/lib/qdrant/storage";
          snapshots_path = "/var/lib/qdrant/snapshots";
        };
        hsnw_index = { on_disk = true; };
        service = {
          host = "127.0.0.1";
          http_port = "6333"; # Change ports to strings to match type definition
          grpc_port = "6334";
        };
        telemetry_disabled =
          "true"; # Change boolean to string to match type definition
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
