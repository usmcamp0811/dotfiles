# modules/apps/k9s.nix
{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.apps.k9s;
in {
  options.campground.apps.k9s = with types; {
    enable = mkBoolOpt false "Whether or not to enable K9s.";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/k3s"
      "The Vault path to the KV containing the Kubeconfig.";
    vault-address = mkOption {
      type = nullOr str;
      default = null; # If null/empty, we skip Vault and copyKUBECONFIG
      description = "The address of your Vault (set to enable Vault-driven kubeconfig).";
    };
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [k9s];

    # Only define the service and Vault agent when vault-address is set
    # (i.e., not null/empty).
    # This prevents copyKUBECONFIG from running when Vault isn’t configured.
    # You can still provide your kubeconfig some other way.
    systemd.services.copyKUBECONFIG = mkIf config.campground.services.vault-agent.enable {
      description = "Copy Kubeconfig to /etc/k8s/";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p /etc/k8s/ && cp /tmp/detsys-vault/kubeconfig /etc/k8s/config && chgrp k8s /etc/k8s/config'";
      };
      wantedBy = ["multi-user.target"];
      after = ["nscd.service"];
    };

    campground.services.vault-agent.services.copyKUBECONFIG = {
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
            "kubeconfig" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                {{ if eq "${cfg.kvVersion}" "v1" }}
                {{ .Data.kubeconfig }}
                {{ else }}
                {{ .Data.data.kubeconfig }}
                {{ end }}
                {{ end }}
              '';
              permissions = "0440";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
