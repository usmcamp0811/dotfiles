{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.hister;
  
  yaml-format = pkgs.formats.yaml { };
  
  # Generate the config file with all settings
  histerConfig = yaml-format.generate "config.yml" (
    lib.filterAttrs (_: v: v != null) {
      app = lib.filterAttrs (_: v: v != null) {
        directory = cfg.dataDir;
        search_url = cfg.app.searchUrl;
        access_token = if cfg.app.accessToken != null then "@HISTER_ACCESS_TOKEN@" else null;
        user_handling = cfg.app.userHandling;
        log_level = cfg.app.logLevel;
        debug_sql = cfg.app.debugSql;
        open_results_on_new_tab = cfg.app.openResultsOnNewTab;
        redirect_on_no_results = cfg.app.redirectOnNoResults;
      };
      
      server = lib.filterAttrs (_: v: v != null) {
        address = cfg.server.address;
        base_url = cfg.server.baseUrl;
        database = cfg.server.database;
        oauth = if cfg.server.oauth != {} then cfg.server.oauth else null;
        oauth_only = if cfg.server.oauth != {} then cfg.server.oauthOnly else null;
      };
      
      indexer = lib.filterAttrs (_: v: v != null) {
        detect_languages = cfg.indexer.detectLanguages;
        directories = if cfg.indexer.directories != [] then cfg.indexer.directories else null;
        max_file_size_mb = cfg.indexer.maxFileSizeMb;
      };
      
      crawler = lib.filterAttrs (_: v: v != null) {
        backend = cfg.crawler.backend;
        backend_options = if cfg.crawler.backendOptions != {} then cfg.crawler.backendOptions else null;
        timeout = cfg.crawler.timeout;
        delay = cfg.crawler.delay;
        user_agent = if cfg.crawler.userAgent != null then cfg.crawler.userAgent else null;
        headers = if cfg.crawler.headers != {} then cfg.crawler.headers else null;
        cookies = if cfg.crawler.cookies != [] then cfg.crawler.cookies else null;
        no_robots = cfg.crawler.noRobots;
      };
      
      semantic_search = if cfg.semanticSearch.enable then 
        (lib.filterAttrs (_: v: v != null) {
          enable = true;
          embedding_endpoint = cfg.semanticSearch.embeddingEndpoint;
          embedding_model = cfg.semanticSearch.embeddingModel;
          api_key = if cfg.semanticSearch.apiKey != null then "@HISTER_EMBEDDING_API_KEY@" else null;
          headers = if cfg.semanticSearch.headers != {} then cfg.semanticSearch.headers else null;
          dimensions = cfg.semanticSearch.dimensions;
          max_context_length = cfg.semanticSearch.maxContextLength;
          chunk_overlap = cfg.semanticSearch.chunkOverlap;
          query_prefix = cfg.semanticSearch.queryPrefix;
          document_prefix = cfg.semanticSearch.documentPrefix;
          similarity_threshold = cfg.semanticSearch.similarityThreshold;
          result_limit = cfg.semanticSearch.resultLimit;
          semantic_weight = cfg.semanticSearch.semanticWeight;
        })
      else null;
      
      hotkeys = if cfg.hotkeys != {} then cfg.hotkeys else null;
      
      sensitive_content_patterns = if cfg.sensitiveContentPatterns != {} then cfg.sensitiveContentPatterns else null;
    }
  );

in
{
  options.fmf.services.hister = with types; {
    enable = mkBoolOpt false "Enable Hister personal search engine.";
    
    package = mkOption {
      type = types.package;
      default = pkgs.hister or (throw "Hister package not available. Please add it to your packages.");
      description = "The Hister package to use.";
    };
    
    dataDir = mkOption {
      type = str;
      default = "/var/lib/hister";
      description = "Directory where Hister stores its data.";
    };
    
    user = mkOption {
      type = str;
      default = "hister";
      description = "User account under which Hister runs.";
    };
    
    group = mkOption {
      type = str;
      default = "hister";
      description = "Group under which Hister runs.";
    };

    # Vault integration
    role-id = mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/hister"
      "The Vault path to the KV containing the Hister Secrets.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    
    # App configuration
    app = {
      searchUrl = mkOption {
        type = str;
        default = "https://google.com/search?q={query}";
        description = "Fallback web search URL.";
      };
      
      accessToken = mkOption {
        type = nullOr str;
        default = null;
        description = "Access token for API authentication. Will be stored in Vault.";
      };
      
      userHandling = mkOption {
        type = bool;
        default = false;
        description = "Enable multi-user mode.";
      };
      
      logLevel = mkOption {
        type = enum [ "debug" "info" "warn" "error" ];
        default = "info";
        description = "Log verbosity level.";
      };
      
      debugSql = mkOption {
        type = bool;
        default = false;
        description = "Enable verbose SQL query logging.";
      };
      
      openResultsOnNewTab = mkOption {
        type = bool;
        default = false;
        description = "Open search results in a new browser tab.";
      };
      
      redirectOnNoResults = mkOption {
        type = bool;
        default = true;
        description = "Redirect to search_url when a query returns no results.";
      };
    };
    
    # Server configuration
    server = {
      address = mkOption {
        type = str;
        default = "127.0.0.1:4433";
        description = "Host and port to listen on.";
      };
      
      baseUrl = mkOption {
        type = nullOr str;
        default = null;
        description = "Public URL of the Hister instance.";
      };
      
      database = mkOption {
        type = str;
        default = "db.sqlite3";
        description = "Database connection string. SQLite filename or PostgreSQL DSN.";
      };
      
      oauth = mkOption {
        type = attrsOf (attrsOf str);
        default = {};
        description = "OAuth/OIDC provider configurations.";
        example = literalExpression ''
          {
            github = {
              client_id = "your-github-client-id";
              client_secret = "your-github-client-secret";
            };
          }
        '';
      };
      
      oauthOnly = mkOption {
        type = bool;
        default = false;
        description = "Disable password login, only allow OAuth.";
      };
    };
    
    # Indexer configuration
    indexer = {
      detectLanguages = mkOption {
        type = bool;
        default = true;
        description = "Enable automatic language detection for indexed pages.";
      };
      
      directories = mkOption {
        type = listOf attrs;
        default = [];
        description = "List of local directories to index.";
        example = literalExpression ''
          [
            {
              path = "~/notes";
              filetypes = [ "txt" "md" ];
            }
            {
              path = "~/Documents/wiki";
            }
          ]
        '';
      };
      
      maxFileSizeMb = mkOption {
        type = int;
        default = 1;
        description = "Maximum file size (in MB) to index.";
      };
    };
    
    # Crawler configuration
    crawler = {
      backend = mkOption {
        type = enum [ "http" "chromedp" "bidi" ];
        default = "http";
        description = "Scraping backend to use.";
      };
      
      backendOptions = mkOption {
        type = attrsOf (either str (either int float));
        default = {};
        description = "Backend-specific options.";
        example = literalExpression ''
          {
            exec_path = "/usr/bin/chromium";
          }
        '';
      };
      
      timeout = mkOption {
        type = int;
        default = 5;
        description = "Request timeout in seconds.";
      };
      
      delay = mkOption {
        type = int;
        default = 0;
        description = "Seconds to wait between requests.";
      };
      
      userAgent = mkOption {
        type = nullOr str;
        default = "Hister";
        description = "Custom User-Agent header.";
      };
      
      headers = mkOption {
        type = attrsOf str;
        default = {};
        description = "Extra HTTP headers.";
      };
      
      cookies = mkOption {
        type = listOf attrs;
        default = [];
        description = "Cookies to send with requests.";
      };
      
      noRobots = mkOption {
        type = bool;
        default = false;
        description = "Disable robots.txt compliance.";
      };
    };
    
    # Semantic search configuration
    semanticSearch = {
      enable = mkOption {
        type = bool;
        default = false;
        description = "Enable semantic search with vector embeddings.";
      };
      
      embeddingEndpoint = mkOption {
        type = str;
        default = "http://localhost:11434/v1/embeddings";
        description = "URL of the embeddings API endpoint.";
      };
      
      embeddingModel = mkOption {
        type = str;
        default = "qwen3-embedding:8b";
        description = "Model name for embeddings.";
      };
      
      apiKey = mkOption {
        type = nullOr str;
        default = null;
        description = "API key for the embedding endpoint. Will be stored in Vault.";
      };
      
      headers = mkOption {
        type = attrsOf str;
        default = {};
        description = "Extra HTTP headers for embedding requests.";
      };
      
      dimensions = mkOption {
        type = int;
        default = 4096;
        description = "Vector dimensionality.";
      };
      
      maxContextLength = mkOption {
        type = int;
        default = 4096;
        description = "Maximum tokens per text chunk.";
      };
      
      chunkOverlap = mkOption {
        type = int;
        default = 128;
        description = "Tokens shared between consecutive chunks.";
      };
      
      queryPrefix = mkOption {
        type = str;
        default = "query: ";
        description = "String prepended to queries before embedding.";
      };
      
      documentPrefix = mkOption {
        type = str;
        default = "";
        description = "String prepended to document chunks before embedding.";
      };
      
      similarityThreshold = mkOption {
        type = float;
        default = 0.1;
        description = "Minimum cosine similarity score.";
      };
      
      resultLimit = mkOption {
        type = int;
        default = 50;
        description = "Maximum semantic hits per query.";
      };
      
      semanticWeight = mkOption {
        type = float;
        default = 0.4;
        description = "Weight applied to semantic score when merging with keyword scores.";
      };
    };
    
    # Hotkeys configuration
    hotkeys = mkOption {
      type = attrsOf (attrsOf str);
      default = {};
      description = "Keyboard shortcuts configuration.";
      example = literalExpression ''
        {
          web = {
            "/" = "focus_search_input";
            "enter" = "open_result";
            "alt+enter" = "open_result_in_new_tab";
          };
        }
      '';
    };
    
    # Sensitive content patterns
    sensitiveContentPatterns = mkOption {
      type = attrsOf str;
      default = {};
      description = "Regex patterns for sensitive content redaction.";
      example = literalExpression ''
        {
          aws_access_key = "AKIA[0-9A-Z]{16}";
          github_token = "(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36}";
        }
      '';
    };
    
    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Open firewall for the configured port.";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Hister service user";
    };

    users.groups.${cfg.group} = {};

    # Ensure data directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/config 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Main Hister service
    systemd.services.hister = {
      description = "Hister Personal Search Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ optional (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) "copy-hister-env.service";
      requires = optional (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) [ "copy-hister-env.service" ];

      environment = {
        HISTER_DATA_DIR = cfg.dataDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = "${pkgs.coreutils}/bin/cp ${histerConfig} ${cfg.dataDir}/config/config.yml";
        ExecStart = if (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) then
          "${pkgs.bash}/bin/bash -c '${pkgs.envsubst}/bin/envsubst < ${cfg.dataDir}/config/config.yml > ${cfg.dataDir}/config/config-final.yml && ${cfg.package}/bin/hister server --config ${cfg.dataDir}/config/config-final.yml'"
        else
          "${cfg.package}/bin/hister server --config ${cfg.dataDir}/config/config.yml";
        
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        SystemCallArchitectures = "native";
        
        # Environment file for secrets
        EnvironmentFile = lib.mkIf (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) 
          "/var/lib/vault/hister.env";
      };
    };

    # Copy secrets from Vault Agent if needed
    systemd.services.copy-hister-env = mkIf (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) {
      description = "Copy Hister environment variables from Vault";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        cp /tmp/detsys-vault/hister.env /var/lib/vault/hister.env
        chmod 600 /var/lib/vault/hister.env
        chown ${cfg.user}:${cfg.group} /var/lib/vault/hister.env
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "hister.service" ];
    };

    # Vault Agent integration for secrets
    fmf.services.vault-agent.services.copy-hister-env = mkIf (cfg.app.accessToken != null || cfg.semanticSearch.apiKey != null) {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = cfg.role-id;
              secret_id_file_path = cfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets = {
        file = {
          files = {
            "hister.env" = {
              text = ''
                ${optionalString (cfg.app.accessToken != null) ''
                  HISTER_ACCESS_TOKEN={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.HISTER_ACCESS_TOKEN }}{{ else }}{{ .Data.data.HISTER_ACCESS_TOKEN }}{{ end }}{{ end }}
                ''}
                ${optionalString (cfg.semanticSearch.apiKey != null) ''
                  HISTER_EMBEDDING_API_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.HISTER_EMBEDDING_API_KEY }}{{ else }}{{ .Data.data.HISTER_EMBEDDING_API_KEY }}{{ end }}{{ end }}
                ''}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 
        (toInt (builtins.elemAt (builtins.split ":" cfg.server.address) 2))
      ];
    };
  };
}
