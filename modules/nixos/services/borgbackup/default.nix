{ lib, config, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.borgbackup;
in
{
  options.campground.services.borgbackup = {
    enable = mkBoolOpt false "Whether or not to enable Borg Backups.";
    jobs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          paths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of paths to backup.";
          };
          encryption = {
            mode = lib.mkOption {
              type = lib.types.str;
              default = "none";
              description = "Encryption mode.";
            };
          };
          environment = {
            BORG_RSH = lib.mkOption {
              type = lib.types.str;
              default = "ssh -o 'StrictHostKeyChecking=no' -i /home/mcamp/.ssh/id_ed25519";
              description = "SSH command for Borg to use.";
            };
          };
          repo = lib.mkOption {
            type = lib.types.str;
            description = "Repository location.";
          };
          compression = lib.mkOption {
            type = lib.types.str;
            default = "auto,zstd";
            description = "Compression method and options.";
          };
          startAt = lib.mkOption {
            type = lib.types.str;
            description = "Schedule for the backup job.";
          };
        };
      }));
      default = {};
      description = "Borg backup jobs configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.borgbackup.jobs = lib.mapAttrs' (name: jobConfig: nameValuePair name jobConfig) cfg.jobs;
  };
}
