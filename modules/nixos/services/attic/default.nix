{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.attic;

  toml-format = pkgs.formats.toml {};

  raw-server-toml = toml-format.generate "server.toml" cfg.settings;

  server-toml = pkgs.runCommand "checked-server.toml" {config = raw-server-toml;} ''
    cat $config

    export ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64="dGVzdCBzZWNyZXQ="
    export ATTIC_SERVER_DATABASE_URL="sqlite://:memory:"

    echo $config
    ${cfg.package}/bin/atticd --mode check-config -f "$config"
    cat < $config > $out
  '';

  is-local-postgres = let
    url = cfg.settings.database.url or "";
    local-db-strings = ["localhost" "127.0.0.1" "/run/postgresql"];
    is-local-db-url = any (flip hasInfix url) local-db-strings;
  in
    config.services.postgresql.enable
    && hasPrefix "postgresql://" url
    && is-local-db-url;
in {
  options.fmf.services.attic = {
    enable = mkEnableOption "Attic";

    package =
      mkOpt types.package pkgs.attic-server "The attic-server package to use.";

    credentials =
      mkOpt (types.nullOr types.path) null
      "The path to an optional EnvironmentFile for the atticd service to use.";

    user = mkOpt types.str "atticd" "The user under which attic runs.";
    group = mkOpt types.str "atticd" "The group under which attic runs.";

    settings =
      mkOpt toml-format.type {} "Settings for the atticd config file.";

    role-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/attic"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !isStorePath cfg.credentials;
        message = "fmf.services.attic.credentials CANNOT be in the Nix Store.";
      }
    ];

    users = {
      users = optionalAttrs (cfg.user == "atticd") {
        atticd = {
          group = cfg.group;
          isSystemUser = true;
        };
      };
      groups = optionalAttrs (cfg.group == "atticd") {atticd = {};};
    };

    fmf = {
      tools.attic = enabled;
      services = {
        attic.settings = {
          database.url =
            mkDefault "postgres://atticd@/atticd?host=/run/postgresql/";

          storage = mkDefault {
            type = "local";
            path = "/var/lib/atticd/storage";
          };
        };
        postgresql = {
          enable = true;
          databases = [
            {
              name = "atticd";
              user = cfg.user;
            }
          ];
        };
        vault-agent = {
          services = {
            "atticd" = {
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
              secrets.environment.templates = {
                atticd = {
                  text = ''
                    {{ with secret "${cfg.vault-path}" }}
                    ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.token  }}{{ else }}{{ .Data.data.token }}{{ end }}
                    {{ end }}
                  '';
                };
              };
            };
          };
        };
      };
    };
    environment.systemPackages = [
      pkgs.attic-client
      pkgs.attic-server
    ];

    environment.etc."attic-config.toml".source = server-toml;
    networking.firewall.allowedTCPPorts = [
      8082
    ];
    systemd.services.atticd = {
      wantedBy = ["multi-user.target"];
      after =
        ["network.target"]
        ++ optionals is-local-postgres [
          "postgresql.service"
          "nss-lookup.target"
        ];

      serviceConfig =
        {
          # ExecStartPre = "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} /var/lib/atticd";
          ExecStart = "${cfg.package}/bin/atticd -f ${server-toml}";
          StateDirectory = "atticd";
          User = cfg.user;
          Group = cfg.group;
          DynamicUser = false;
          Restart = "always";
        }
        // optionalAttrs (cfg.credentials != null) {
          EnvironmentFile = mkDefault cfg.credentials;
        };
    };
  };
}
# Do this when you have problems trying to create a cache:
# be sure to have the token in the environment
# sudo -E atticadm make-token \
#   --validity "10y" \
#   --sub "campground*" \
#   --pull "campground*" \
#   --push "campground*" \
#   --create-cache "campground*" \
#   --configure-cache "campground*" \
#   --configure-cache-retention "campground*" \
#   --destroy-cache "campground*" \
#   --config /etc/attic-config.toml

