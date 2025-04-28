{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.k3s;
  ipRanges = [ "10.8.200.100-10.8.200.150" ];

  manifests = {
    metallb-native = {
      source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml";
        sha256 = "sha256-lRBl6FaSqhBvG7XVpIfZMGFUkjp5SrHYISKIHLr1iOQ=";
      };
    };
    metallb-config = {
      content = [
        {
          apiVersion = "metallb.io/v1beta1";
          kind = "IPAddressPool";
          metadata = {
            name = "default-pool";
            namespace = "metallb-system";
          };
          spec = {
            addresses = [ "10.8.200.100-10.8.200.150" ];
          };
        }
        {
          apiVersion = "metallb.io/v1beta1";
          kind = "L2Advertisement";
          metadata = {
            name = "default";
            namespace = "metallb-system";
          };
        }
      ];
    };
  };
in
{
  options.campground.services.k3s = {
    enable = mkEnableOption "Enable k3s cluster";
    package = lib.mkPackageOption pkgs "k3s_1_31" { };
    config = mkOption {
      type = types.attrs;
      default = {
        disable = [ "servicelb" "traefik" ];
      };
      description = "K3s Config Yaml";
      example = literalExpression ''
        {
          disable = ["servicelb"];
          clusterInit = true;
          tlsSan = [ "my-lb.example.com" "10.0.0.10" ];
          nodeName = "chesty";
        }
      '';
    };
    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "The role of this k3s node.";
    };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = "";
      description = "K3s server URL (used by agents).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags passed to k3s.";
    };

    clusterInit = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this node should store the k3s token into Vault.";
    };

    role-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/k3s"
        "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    services.k3s = {
      inherit manifests;
      enable = true;
      package = cfg.package;
      clusterInit = cfg.clusterInit;
      role = cfg.role;
      tokenFile = mkIf (!cfg.clusterInit) "/var/lib/rancher/k3s/server/node-token";
      serverAddr = cfg.serverAddr;
      # setKubeConfig = true;
      # snapshotter = "nix";
      configPath =
        if cfg.role == "server"
        then "/etc/rancher/k3s/config.yaml"
        else null;
      moreFlags = cfg.extraFlags;
    };

    systemd.services.store-k3s-token = mkIf cfg.clusterInit {
      description = "Store K3s node-token in Vault";
      after = [
        "k3s.service"
        "vault-agent.service"
        "network-online.target"
      ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "store-k3s-token" ''
          set -e

          echo "Waiting for K3s to be fully ready..."

          until [ -f /var/lib/rancher/k3s/server/node-token ]; do
            sleep 5
          done

          echo "Reading K3s node-token..."
          NODE_TOKEN=$(< /var/lib/rancher/k3s/server/node-token)

          VAULT_PATH="${cfg.vault-path}"
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
          SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
          export VAULT_TOKEN

          echo "Storing K3s node-token in Vault at $VAULT_PATH"
          ${pkgs.vault}/bin/vault kv put "$VAULT_PATH" node_token="$NODE_TOKEN"

          echo "Done storing K3s token."
        '';
        RemainAfterExit = true;
      };
    };

    environment.systemPackages = [ cfg.package ];

    systemd.services.k3s.preStart = ''
      # always write config.yaml
      ${pkgs.coreutils}/bin/mkdir -p /etc/rancher/k3s
      ${pkgs.coreutils}/bin/echo '${lib.generators.toYAML {} cfg.config}' > /etc/rancher/k3s/config.yaml

      # conditionally set node-token
      ${lib.optionalString (!cfg.clusterInit) ''
        mkdir -p /var/lib/rancher/k3s/server
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/node-token
      ''}
    '';
    campground.services.vault-agent.services.k3s = {
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
            "k3s-token" = {
              text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.node_token }}{{ else }}{{ .Data.data.node_token }}{{ end }}{{ end }}'';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
