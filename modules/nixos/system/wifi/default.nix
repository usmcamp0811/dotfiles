{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.wifi;
in {
  # Save Wifi Passwords in Vault with the SSID as the Key to the KV store
  options.fmf.system.wifi = with types; {
    enable = mkBoolOpt false "Whether or not to enable Wifi.";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/wifi"
      "The Vault path to the KV containing the Wifi Secrets.";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    networks = mkOption {
      type = attrsOf (submodule {
        options = {
          ssid = mkOption {
            type = str;
            description = "The SSID of the WiFi network.";
          };
        };
      });
      default = {};
      description = "A list of WiFi networks to connect to.";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.wifi_passwords = {
      description = "Set/update all Wifi Passwords";
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/wifi-passwords";
        Type = "oneshot";
      };
    };
    fmf.services.vault-agent.services.wifi_passwords = {
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
            "wifi-passwords" = {
              text = builtins.concatStringsSep "\n" (lib.mapAttrsToList
                (name: network: ''
                  #!/bin/sh
                  SSID="${network.ssid}"
                  PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${name} }}{{ else }}{{ .Data.data.${name} }}{{ end }}{{ end }}

                  if ${pkgs.networkmanager}/bin/nmcli con show | grep -q $SSID; then
                    ${pkgs.networkmanager}/bin/nmcli con delete id $SSID
                  fi
                  ${pkgs.networkmanager}/bin/nmcli dev wifi connect $SSID password $PASSWORD
                '')
                cfg.networks);
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
