{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.nix-ai;
  extraFlagsString = concatStringsSep " " cfg.extraFlags;
in {
  options.campground.services.nix-ai = with types; {
    enable = mkBoolOpt false "Enable nix-ai;";

    port = mkOption {
      type = types.int;
      default = 18080;
      description = "The port for nix-ai service.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The host for nix-ai service.";
    };

    model = mkOption {
      type = types.str;
      default = "${pkgs.campground.mistral-7b-instruct}";
      description = "The host for nix-ai service.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the nix-ai service.";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ textgen-nvidia ];

    # users.users.localai = {
    #   isNormalUser = false;
    #   isSystemUser = true;
    #   description = "LocalAI System User";
    #   group = "localai";
    #   extraGroups = [ "localai" ];
    #   home = "/var/lib/nix-ai";
    # };
    #
    # users.groups.localai = { };
    #
    # systemd.services.nix-ai = {
    #   description = "Local AI Service";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   environment = {
    #     LOCALAI_MODELS_PATH = "/var/lib/nix-ai/models";
    #     LOCALAI_BACKEND_ASSETS_PATH = "/var/lib/nix-ai";
    #     LOCALAI_IMAGE_PATH = "/var/lib/nix-ai/image";
    #     LOCALAI_AUDIO_PATH = "/var/lib/nix-ai/audio";
    #     LOCALAI_UPLOAD_PATH = "/var/lib/nix-ai/upload";
    #     LOCALAI_CONFIG_PATH = "/var/lib/nix-ai";
    #     LOCALAI_CONFIG_DIR = "/var/lib/nix-ai/config";
    #   };
    #   serviceConfig = {
    #     Restart = "always";
    #     User = "localai";
    #     Group = "localai";
    #     WorkingDirectory = "/var/lib/nix-ai";
    #     ExecStart = ''
    #       ${pkgs.nix-ai}/bin/nix-ai run --address "${cfg.host}:${
    #         toString cfg.port
    #       }" ${extraFlagsString}
    #     '';
    #   };
    # };
    # system.activationScripts.createMyAppDir = ''
    #   mkdir -p /var/lib/nix-ai
    #   cp ${cfg.model} /var/lib/nix-ai/models/mistral-7b-instruct.gguf
    #   chown -R localai:localai /var/lib/nix-ai
    # '';

  };

}
