{ pkgs, lib, config, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.ollama;

in {
  options.fmf.services.ollama = with types; {
    enable = mkBoolOpt false "Enable Ollama.";
    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Set arbitrary environment variables for the Ollama service. These are only seen by the Ollama server (systemd service), not normal invocations like ollama run.
      '';
    };
    package = mkOption {
      type = types.package;
      default = pkgs.ollama-cuda;
      description = ''
        The package to be used for Ollama service.
      '';
    };
    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        The address on which the Ollama server listens.
      '';
    };
    port = mkOption {
      type = types.int;
      default = 11434;
      description = ''
        The port on which the Ollama server listens.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "ollama";
      description = ''
        The user that runs the Ollama service.
      '';
    };
    group = mkOption {
      type = types.str;
      default = "ollama";
      description = ''
        The group that runs the Ollama service.
      '';
    };
    loadModels = mkOption {
      type = types.listOf str;
      default = [ ];
      description = ''
        Download these models using ollama pull as soon as ollama.service has started.

        This creates a systemd unit ollama-model-loader.service.

        Search for models of your choice from: https://ollama.com/library
      '';
    };
    modelsDir = mkOption {
      type = types.path;
      default = "/var/lib/ollama/models";
      description = ''
        The directory where the Ollama models are stored.
      '';
    };
    home = mkOption {
      type = types.path;
      default = "/var/lib/ollama";
      description = ''
        The home directory that the ollama service is started in.
      '';
    };
    acceleration = mkOption {
      type = types.nullOr (types.enum [ false "rocm" "cuda" ]);
      default = null;
      description = ''
        What interface to use for hardware acceleration.
        - null: default behavior depending on GPU support
        - false: disable GPU, only use CPU
        - "rocm": supported by most modern AMD GPUs
        - "cuda": supported by most modern NVIDIA GPUs
      '';
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      home = cfg.home;
      environmentVariables = cfg.environmentVariables;
      host = cfg.host;
      port = cfg.port;
      user = cfg.user;
      group = cfg.group;
      models = cfg.modelsDir;
      loadModels = cfg.loadModels;
      acceleration = cfg.acceleration;
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
