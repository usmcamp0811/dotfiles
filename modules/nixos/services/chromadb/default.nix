{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.chromadb;
in {
  options.campground.services.chromadb = with types; {
    enable = mkBoolOpt false "Enable ChromaDB.";

    package = mkOption {
      type = package;
      default = pkgs.python312Packages.chromadb;
      example = literalExpression "pkgs.python3Packages.chromadb";
      description = "ChromaDB package to use.";
    };

    host = mkOpt str "0.0.0.0" ''
      Defines the IP address by which ChromaDB will be accessible.
    '';

    port = mkOpt int 8000 ''
      Defines the port number to listen on.
    '';

    logFile = mkOption {
      type = path;
      default = "/var/log/chromadb/chromadb.log";
      description = "Specifies the location of the file for logging output.";
    };

    dbpath =
      mkStrOpt "/var/lib/chromadb" "Location where ChromaDB stores its files";

    openFirewall = mkBoolOpt false ''
      Whether to automatically open the specified TCP port in the firewall.
    '';
  };

  config = mkIf cfg.enable {
    services.chromadb = {
      enable = true;
      package = cfg.package;
      host = cfg.host;
      port = cfg.port;
      logFile = cfg.logFile;
      dbpath = cfg.dbpath;
      openFirewall = cfg.openFirewall;
    };
  };
}
