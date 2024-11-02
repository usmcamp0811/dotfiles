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

    port = mkOption {
      type = types.intRange 0 65535;
      default = 11434;
      description = ''
        The port on which the Ollama server listens.
      '';
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The host address that the Ollama server HTTP interface listens to.
      '';
    };

    home = mkOption {
      type = types.str;
      default = "/var/lib/ollama";
      description = ''
        The home directory that the Ollama service is started in.
      '';
    };

    loadModels = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Download these models using `ollama pull` as soon as the Ollama service has started.
        Search for models from: https://ollama.com/library
      '';
    };

    openFirewall = mkBoolOpt false
      "Whether to open the firewall for Ollama, adding its port to allowed TCP ports.";

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
      port = cfg.port;
      host = cfg.host;
      home = cfg.home;
      loadModels = cfg.loadModels;
      openFirewall = cfg.openFirewall;
      acceleration = cfg.acceleration;
    };
  };
}
