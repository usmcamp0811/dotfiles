# Example Hister NixOS configuration
# This file demonstrates various ways to configure the Hister service

{ config, pkgs, ... }:

{
  # Basic configuration
  fmf.services.hister = {
    enable = true;
    
    # Server configuration
    server = {
      address = "0.0.0.0:4433";
      baseUrl = "https://hister.example.com";
    };
    
    # Optional: Open firewall port
    openFirewall = true;
    
    # Optional: Index local directories
    indexer.directories = [
      {
        path = "~/notes";
        filetypes = [ "txt" "md" ];
      }
      {
        path = "~/Documents";
        filetypes = [ "md" "org" "txt" ];
        excludes = [ "*secret*" "*.tmp" ];
      }
    ];
    
    # Optional: Enable semantic search with Ollama
    # semanticSearch = {
    #   enable = true;
    #   embeddingEndpoint = "http://localhost:11434/v1/embeddings";
    #   embeddingModel = "nomic-embed-text";
    #   dimensions = 768;
    #   maxContextLength = 512;
    #   queryPrefix = "search_query: ";
    #   documentPrefix = "search_document: ";
    # };
    
    # Optional: Configure access token (via Vault)
    # app.accessToken = "placeholder"; # Actual value from Vault
    # vault-path = "secret/campground/hister";
    
    # Optional: Enable multi-user mode with OAuth
    # app.userHandling = true;
    # server.oauth = {
    #   github = {
    #     client_id = "your-client-id";
    #     client_secret = "your-client-secret";
    #   };
    # };
    
    # Optional: Custom hotkeys
    # hotkeys = {
    #   web = {
    #     "/" = "focus_search_input";
    #     "enter" = "open_result";
    #     "alt+enter" = "open_result_in_new_tab";
    #   };
    # };
  };
  
  # Optional: If you want to use PostgreSQL instead of SQLite
  # services.postgresql = {
  #   enable = true;
  #   ensureDatabases = [ "hister" ];
  #   ensureUsers = [{
  #     name = "hister";
  #     ensurePermissions = {
  #       "DATABASE hister" = "ALL PRIVILEGES";
  #     };
  #   }];
  # };
  # 
  # fmf.services.hister.server.database = 
  #   "host=localhost user=hister dbname=hister port=5432 sslmode=disable TimeZone=UTC";
}
