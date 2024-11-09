{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.ollama;
in {
  options.campground.services.ollama = with types; {
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

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0:11434";
      description = ''
        The address on which the Ollama server listens.
      '';
    };

    home = mkOption {
      type = types.str;
      default = "/var/lib/ollama";
      description = ''
        The home directory that the Ollama service is started in.
      '';
    };

    models = mkOption {
      type = types.str;
      default = "%S/ollama/models";
      description = ''
        List of models to load at startup. These will be downloaded using `ollama pull`.
      '';
    };

    writablePaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional paths that the Ollama service has write access to.
      '';
    };

    sandbox = mkBoolOpt true "Enable sandboxing for the Ollama service.";

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
      environmentVariables = cfg.environmentVariables;
      listenAddress = cfg.listenAddress;
      home = cfg.home;
      models = cfg.models;
      writablePaths = cfg.writablePaths;
      sandbox = cfg.sandbox;
      acceleration = cfg.acceleration;
    };
  };
}
