{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground;
let
  cfg = config.campground.services.borgbackup;
  fileExporterDir = config.campground.services.prometheus.fileExporterDir;

in
{
  options.campground.services.borgbackup = with types; {
    enable = mkBoolOpt false "Whether or not to enable Borg Backups.";
    jobs = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }: # Access the config which contains `_module.args`
          {
            options = {
              paths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "List of paths to backup.";
              };
              encryption = {
                mode = lib.mkOption {
                  type = lib.types.str;
                  default = "repokey-blake2";
                  description = "Encryption mode.";
                };
                passCommand = lib.mkOption {
                  type = lib.types.str;
                  default = "cat /var/lib/vault/borg-passphrase";
                  description = "encryptiong key";
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
              postHook = lib.mkOption {
                #TODO: Think about adding hte default prom script outside of the options so it always happens
                type = lib.types.lines;
                description = ''
                  Shell commands to run just before exit. They are executed
                  even if a previous command exits with a non-zero exit code.
                  The latter is available as `$exitStatus`.
                '';
                default = ''
                  jobName="${config._module.args.name}"
                  mkdir -p ${fileExporterDir}
                  if [ $exitStatus -eq 0 ]; then
                    echo "borg_backup_success{job=\"$jobName\"} 1" > ${fileExporterDir}/borg-backup-$jobName.prom
                  else
                    echo "borg_backup_success{job=\"$jobName\"} 0" > ${fileExporterDir}/borg-backup-$jobName.prom
                  fi
                  echo "borg_backup_last_run{job=\"$jobName\"} $(date +%s)" >> ${fileExporterDir}/borg-backup-$jobName.prom
                '';
              };
              readWritePaths = lib.mkOption {
                type = with lib.types; listOf path;
                description = ''
                  By default, borg cannot write anywhere on the system but
                  `$HOME/.config/borg` and `$HOME/.cache/borg`.
                  If, for example, your preHook script needs to dump files
                  somewhere, put those directories here.
                '';
                default = [ fileExporterDir ];
                example = [ "/var/backup/mysqldump" ];
              };
              extraArgs = mkOption {
                type = with types; coercedTo (listOf str) escapeShellArgs str;
                description = lib.mdDoc ''
                  Additional arguments for all {command}`borg` calls the
                  service has. Handle with care.
                '';
                default = [ ];
                example = [ "--remote-path=/path/to/borg" ];
              };
            };
          }
        )
      );
      default = { };
      description = "Borg backup jobs configuration.";
    };

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/borg"
        "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [
        "v1"
        "v2"
      ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = lib.mkIf cfg.enable {
    services.borgbackup.jobs = lib.mapAttrs' (name: jobConfig: nameValuePair name jobConfig) cfg.jobs;

    systemd.services = (
      lib.genAttrs (lib.attrNames cfg.jobs) (name: {
        description = "Copy the passphrase for ${name} Borg Backup job";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = ''if [ -f /tmp/detsys-vault/${name}-borg-passphrase ]; then cp /tmp/detsys-vault/${name}-borg-passphrase /var/lib/vault/${name}-borg-passphrase; fi'';

        };
        wantedBy = [ "multi-user.target" ];
      })
    );
    campground.services.vault-agent.services = lib.genAttrs (lib.attrNames cfg.jobs) (name: {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };

      secrets = {
        file = {
          files = {
            "${name}-borg-passphrase" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${name} }}{{ else }}{{ .Data.data.${name} }}{{ end }}{{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    });
  };
}
