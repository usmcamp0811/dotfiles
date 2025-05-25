{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.attic-watch-store;
in
{
  options.campground.services.attic-watch-store = {
    enable = mkEnableOption "Attic";
    cache-name =
      mkOpt types.str "campground"
        "Name of the Attic Cache that we want to push things to";
    endpoint =
      mkOpt types.str "https://attic.aicampground.com" "URL of the Cache";

    user = mkOpt types.str "atticd" "The user under which attic runs.";
    group = mkOpt types.str "atticd" "The group under which attic runs.";

    role-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/attic"
        "The Vault path to the KV containing the KVs that are for the attic cache token";
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    users = {
      users = optionalAttrs (cfg.user == "atticd") {
        atticd = {
          group = cfg.group;
          isNormalUser = false;
          isSystemUser = true;
        };
      };
      groups = optionalAttrs (cfg.group == "atticd") { atticd = { }; };
    };

    systemd.services.attic-watch-store = {
      wantedBy = [ "multi-user.target" ];
      after = [ "atticd.service" ];
      environment = { HOME = "/var/lib/atticd"; };
      serviceConfig = {
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store ${cfg.cache-name}";
        User = cfg.user;
        Group = cfg.group;
        DynamicUser = false;
        WorkingDirectory = "/var/lib/atticd";
        Restart = "always";
      };
      preStart = ''
        mkdir -p /var/lib/atticd/.config/attic
        cp /tmp/detsys-vault/attic-config.toml /var/lib/atticd/.config/attic/config.toml
      '';
    };

    campground = {
      tools.attic = enabled;
      services = {
        vault-agent = {
          services = {
            "attic-watch-store" = {
              settings = {
                # replace with the address of your vault
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
                    "attic-config.toml" = {
                      text = ''
                        default-server = "${cfg.cache-name}"
                        [servers.${cfg.cache-name}]
                        endpoint = "${cfg.endpoint}"
                        token = "{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${cfg.cache-name} }}{{ else }}{{ .Data.data.${cfg.cache-name} }}{{ end }}{{ end }}"
                      '';
                      permissions = "0600";
                      change-action = "restart";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
