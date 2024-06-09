{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.local-ai;
  extraFlagsString = concatStringsSep " " cfg.extraFlags;
in {
  options.campground.services.local-ai = with types; {
    enable = mkBoolOpt false "Enable local-ai;";

    port = mkOption {
      type = types.int;
      default = 18080;
      description = "The port for local-ai service.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The host for local-ai service.";
    };

    model = mkOption {
      type = types.str;
      default = "${pkgs.campground.mistral-7b-instruct}";
      description = "The host for local-ai service.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the local-ai service.";
    };
  };

  config = mkIf cfg.enable {

    users.users.localai = {
      isNormalUser = false;
      isSystemUser = true;
      description = "LocalAI System User";
      group = "localai";
      extraGroups = [ "localai" ];
      home = "/var/lib/local-ai";
    };

    users.groups.localai = { };

    systemd.services.local-ai = {
      description = "Local AI Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        LOCALAI_MODELS_PATH = "/var/lib/local-ai/models";
        LOCALAI_BACKEND_ASSETS_PATH = "/var/lib/local-ai";
        LOCALAI_IMAGE_PATH = "/var/lib/local-ai/image";
        LOCALAI_AUDIO_PATH = "/var/lib/local-ai/audio";
        LOCALAI_UPLOAD_PATH = "/var/lib/local-ai/upload";
        LOCALAI_CONFIG_PATH = "/var/lib/local-ai";
        LOCALAI_CONFIG_DIR = "/var/lib/local-ai/config";
      };
      serviceConfig = {
        Restart = "always";
        User = "localai";
        Group = "localai";
        WorkingDirectory = "/var/lib/local-ai";
        ExecStart = ''
          ${pkgs.local-ai}/bin/local-ai run --address "${cfg.host}:${
            toString cfg.port
          }" ${extraFlagsString}
        '';
      };
    };
    system.activationScripts.createMyAppDir = ''
      mkdir -p /var/lib/local-ai
      chown localai:localai /var/lib/local-ai
    '';

  };

}
