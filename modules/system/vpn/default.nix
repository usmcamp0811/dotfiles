{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.system.vpn;
in
{
  options.campground.system.vpn = with types; {
    enable = mkBoolOpt false "Whether or not to enable VPN.";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    networks = mkOption {
      type = attrsOf (submodule {
        options = {
          key = mkOption {
            type = str;
            description = "The key of the VPN network.";
          };
        };
      });
      default = {};
      description = "A list of VPN networks to connect to.";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.vpn_configs = {
      description = "Set/update all VPN configs";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/vpn-configs";
        Type = "oneshot";
      };
    };
    campground.services.vault-agent.services.vpn_configs = {
      settings = {
        vault.address = cfg.vault-address;
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
      secrets = {
        file = {
          files = { 
            "vpn-configs" = {
              text = builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: network: ''
                #!/bin/sh
                VPN_NAME="${name}"
                OVPN_FILE="/tmp/detsys-vault/vpn-configs/${name}.ovpn"
                cat <<EOF >$OVPN_FILE
      {{ with secret "secret/campground/vpn" }}{{ .Data.${network.key} }}{{ end }}
      EOF
                if ${pkgs.networkmanager}/bin/nmcli con show | grep -q $VPN_NAME; then
                  ${pkgs.networkmanager}/bin/nmcli con delete id $VPN_NAME
                fi
                ${pkgs.networkmanager}/bin/nmcli con import type openvpn file $OVPN_FILE
              '') cfg.networks);
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}

