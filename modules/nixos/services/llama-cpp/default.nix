{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.llama-cpp;
in {
  options.campground.services.llama-cpp = with types; {
    enable = mkBoolOpt false "Enable llama-cpp;";

    package = mkOption {
      type = types.package;
      default = pkgs.llama-cpp;
      description = "The llama-cpp package to use.";
    };

    port = mkOption {
      type = types.int;
      default = 8080;
      description = "The port for llama-cpp service.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for llama-cpp service.";
    };

    host = mkOption {
      type = types.str;
      default = "localhost";
      description = "The host for llama-cpp service.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the llama-cpp service.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.llama-cpp = {
      description = "llama-cpp service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart =
          "${cfg.package}/bin/llama-cpp --port ${cfg.port} --host ${cfg.host} ${
            concatStringsSep " " cfg.extraFlags
          }";
        Restart = "always";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };

}
