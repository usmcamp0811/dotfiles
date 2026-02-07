{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.llama-cpp;
in {
  options.fmf.services.llama-cpp = with types; {
    enable = mkBoolOpt false "Enable llama-cpp;";

    port = mkOption {
      type = types.int;
      default = 18080;
      description = "The port for llama-cpp service.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for llama-cpp service.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The host for llama-cpp service.";
    };

    model = mkOption {
      type = types.str;
      default = "${pkgs.fmf.mistral-7b-instruct}";
      description = "The host for llama-cpp service.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the llama-cpp service.";
    };
  };

  config = mkIf cfg.enable {
    services.llama-cpp = {
      enable = true;
      extraFlags = cfg.extraFlags;
      model = cfg.model;
      host = cfg.host;
      port = cfg.port;
      openFirewall = cfg.openFirewall;
    };
  };

}
