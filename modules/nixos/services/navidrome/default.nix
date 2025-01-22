{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.navidrome;
in {
  options.campground.services.navidrome = with types; {
    enable = mkEnableOption "Navidrome Music Server";

    package =
      mkOpt types.package pkgs.navidrome "The Navidrome package to use.";

    music-folder = mkOpt types.str "/export/media/music" "Music Folder";
    port = mkOpt types.int 4533 "Port to use for Navidrome.";
    address = mkOpt types.str "0.0.0.0" "Listen address for Navidrome.";
    user = mkOpt types.str "navidrome" "The user under which Navidrome runs.";
    group = mkOpt types.str "navidrome" "The group under which Navidrome runs.";
    openFirewall =
      mkOpt types.bool false "Whether to open the firewall for Navidrome.";
    enableInsightsCollector = mkOpt types.bool true
      "Enable anonymous insights collection for Navidrome.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/navidrome"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    # Use the provided NixOS module
    services.navidrome = {
      enable = true;
      package = cfg.package;
      settings = {
        Port = cfg.port;
        Address = cfg.address;
        EnableInsightsCollector = cfg.enableInsightsCollector;
        MusicFolder = cfg.music-folder;
      };
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    users = {
      users = {
        "${cfg.user}" = {
          group = "${cfg.group}";
          isSystemUser = true;
        };
      };
      groups = { "${cfg.group}" = { }; };
    };
    campground.services.vault-agent.services.navidrome = {
      settings = {
        vault.address =
          cfg.vault-address; # Replace with your Vault server address
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
      secrets.environment.templates = {
        navidrome = {
          text = ''
            ND_AUTHBACKEND=oidc
            ND_OIDC_CLIENTID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENTID }}{{ else }}{{ .Data.data.OIDC_CLIENTID }}{{ end }}{{ end }}
            ND_OIDC_CLIENTSECRET={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENTSECRET }}{{ else }}{{ .Data.data.OIDC_CLIENTSECRET }}{{ end }}{{ end }}
            ND_OIDC_ENDPOINT={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_ENDPOINT }}{{ else }}{{ .Data.data.OIDC_ENDPOINT }}{{ end }}{{ end }}
            ND_OIDC_REDIRECTURI={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_REDIRECTURI }}{{ else }}{{ .Data.data.OIDC_REDIRECTURI }}{{ end }}{{ end }}
            ND_OIDC_SCOPES={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_SCOPES }}{{ else }}{{ .Data.data.OIDC_SCOPES }}{{ end }}{{ end }}
          '';
        };
      };
    };
  };
}
