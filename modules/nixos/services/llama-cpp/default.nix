{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.llama-cpp;
in {
  options.campground.services.llama-cpp = with types; {
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
