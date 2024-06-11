{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.nix-ai;
  extraFlagsString = concatStringsSep " " cfg.extraFlags;
in {
  options.campground.services.nix-ai = with types; {
    enable = mkBoolOpt false "Enable nix-ai;";

    package = mkOption {
      type = types.package;
      default = pkgs.textgen-nvidia;
      description = "The package to use for the custom service";
    };

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

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the nix-ai service.";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ textgen-nvidia ];

    users.users.localai = {
      isNormalUser = false;
      isSystemUser = true;
      description = "LocalAI System User";
      group = "nixai";
      extraGroups = [ "nixai" ];
      home = "/var/lib/nix-ai";
    };

    users.groups.localai = { };

    systemd.services.nix-ai = {
      description = "Local AI Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        User = "nixai";
        Group = "nixai";
        WorkingDirectory = "/var/lib/nix-ai";
        ExecStart = ''

          ${pkgs.nix-ai}/bin/textgen --model-dir /var/lib/nix-ai/models --listen --api --listen-port ${
            toString cfg.port
          } ${extraFlagsString}
        '';
      };
    };
    system.activationScripts.createMyAppDir = ''
      mkdir -p /var/lib/nix-ai
      chown -R nixai:nixai /var/lib/nix-ai
    '';

  };

}
