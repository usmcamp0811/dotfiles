{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.open-webui;
in {
  options.campground.services.open-webui = with types; {
    enable = mkBoolOpt false "Enable Open-WebUI.";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/open-webui";
      description = ''
        Directory for Open-WebUI state files.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 18580;
      description = ''
        The port on which Open-WebUI listens.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.open-webui;
      description = ''
        The package to be used for Open-WebUI service.
      '';
    };

    openFirewall = mkBoolOpt false "Open firewall for Open-WebUI.";

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        The host address for Open-WebUI.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to a file containing environment variables for the Open-WebUI service.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        # VECTOR_DB = "chroma";
        # CHROMA_TENANT = "campground";
        # CHROMA_DATABASE = "campground";
        # CHROMA_HTTP_HOST = "lucas";
        # CHROMA_HTTP_PORT = "18000";
        DOCS_DIR = "/var/lib/open-webui/docs";
        RAG_TOP_K = "5";
        RAG_RELEVANCE_THRESHOLD = "0";
        ENABLE_RAG_HYBRID_SEARCH = "True";
        RAG_EMBEDDING_ENGINE = "ollama";
      };
      description = ''
        Additional environment variables for the Open-WebUI service.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.open-webui = {
      enable = true;
      stateDir = cfg.stateDir;
      port = cfg.port;
      package = cfg.package;
      openFirewall = cfg.openFirewall;
      host = cfg.host;
      # environmentFile = cfg.environmentFile;
      environment = cfg.environment;
    };
  };
}
