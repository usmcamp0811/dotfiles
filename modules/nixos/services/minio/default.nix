{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.minio;
in
{
  options.campground.services.minio = with types; {
    enable = mkBoolOpt false "Enable minio;";
    dataDir = mkOpt str "/var/lib/minio/data" "Data directory for MinIO server.";
    configDir = mkOpt str "/var/lib/minio/config" "Config directory";
    listenAddress = mkOpt str ":9000" "IP addres and port of the server";
    consoleAddress = mkOpt str ":9001" "IP addres and port of the web UI.";
    region = mkOpt str "us-east-1" "where the server is at... defaults to the same as AWS";
    
    
  };

  config = mkIf cfg.enable {

   services.minio = {
      enable = true;
      listenAddress = cfg.listenAddress;
      consoleAddress = cfg.consoleAddress;
      dataDir = [ cfg.dataDir ];
      configDir = cfg.configDir;
      region = cfg.region;
    };

  };
}
