{ lib, config, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.services.attic;
in
{
  options.campground.services.attic = {
    enable = mkEnableOption "Attic";
    cache = mkOpt types.str "campground" "Name of the Attic Cache that we want to push things to";

    role-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/attic" "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
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
          isSystemUser = true;
        };
      };
      groups = optionalAttrs (cfg.group == "atticd") {
        atticd = { };
      };
    };

    systemd.services.attic-watch-store = {
      wantedBy = [ "multi-user.target" ];
      after = [ "atticd.service" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/attic watch-store $cfg.cache";
        StateDirectory = "atticd";
        User = cfg.user;
        Group = cfg.group;
        DynamicUser = false;
      };
    };

    # campground = {
    #   tools.attic = enabled;
    #   services = {
    #     vault-agent = {
    #       services = {
    #         "atticd" = {
    #           settings = {       # replace with the address of your vault
    #             vault.address = "https://vault.lan.aicampground.com";
    #             auto_auth = {
    #               method = [{
    #                 type = "approle";
    #                 config = {
    #                   role_id_file_path = cfg.role-id;
    #                   secret_id_file_path = cfg.secret-id;
    #                   remove_secret_id_file_after_reading = false;
    #                 };
    #               }];
    #             };
    #           };
    #           secrets.environment.templates = {
    #             atticd = {
    #               text = ''
    #                 {{ with secret "${cfg.vault-path}" }}
    #                 ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.token  }}{{ else }}{{ .Data.data.token }}{{ end }}
    #                 {{ end }}
    #               '';
    #             };
    #           };
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
