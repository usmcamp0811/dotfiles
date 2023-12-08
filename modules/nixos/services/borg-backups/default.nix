{ lib, config, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.borgbackup;
  
  borgJob = name: job: ''
    borg create --compression ${job.compression} ${builtins.concatStringsSep " " (map (path: "--exclude " + path) job.exclude)} ${job.repo}::'{now}' ${job.paths}
  '';
in
{
  options.campground.services.borgbackup = {
    enable = mkEnableOption "BorgBackup service";
    
    jobs = mkOption {
      type = attrsOf (submodule {
        options = {
          paths = mkOption {
            type = str;
            description = "Path to backup";
          };
          exclude = mkOption {
            type = listOf str;
            default = [];
            description = "Paths to exclude from backup";
          };
          repo = mkOption {
            type = str;
            description = "Backup repository location";
          };
          encryption = mkOption {
            type = attrs;
            description = "Encryption settings";
          };
          compression = mkOption {
            type = str;
            default = "auto,lzma";
            description = "Compression method and level";
          };
          startAt = mkOption {
            type = str;
            default = "daily";
            description = "When to run the backup job";
          };
        };
      });
      description = "Backup jobs configuration";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services = lib.mkMerge (lib.mapAttrsToList (name: job: {
      "borgbackup-${name}" = {
        description = "BorgBackup job ${name}";
        script = borgJob name job;
        serviceConfig.Type = "oneshot";
        startAt = job.startAt;
      };
    }) cfg.jobs);
  };
}
