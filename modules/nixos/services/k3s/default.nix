{ lib
, config
, pkgs
, inputs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.k3s;
  kubelib = inputs.kube-gen.lib { inherit pkgs; };
  external-secrets-yaml = ./external-secrets-vault-creds.yaml;
  serverAddr = "https://${cfg.serverAddr}:6443";
  ipRanges = [ "10.8.200.100-10.8.200.150" ];
  # image = pkgs.dockerTools.pullImage {
  #   imageName = "nginx";
  #   imageDigest = "sha256:4ff102c5d78d254a6f0da062b3cf39eaf07f01eec0927fd21e219d0af8bc0591";
  #   hash = "sha256-Fh9hWQWgY4g+Cu/0iER4cXAMvCc0JNiDwGCPa+V/FvA=";
  #   finalImageTag = "1.27.4-alpine";
  #   arch = "amd64";
  # };

  # external-secrets =
  #   pkgs.runCommand "external-secrets"
  #   {
  #     nativeBuildInputs = with pkgs; [
  #       kubernetes-helm
  #       cacert
  #     ];
  #     outputHashAlgo = "sha256";
  #     outputHash = "sha256-U2XjNEWE82/Q3KbBvZLckXbtjsXugUbK6KdqT5kCccM=";
  #   }
  #   ''
  #     export HOME="$PWD"
  #
  #     helm repo add external-secrets https://charts.external-secrets.io
  #     helm pull external-secrets/external-secrets --version v0.16.1
  #     mv ./*.tgz $out
  #   '';

  charts = {
    external-secrets =
      pkgs.runCommand "external-secrets.tgz"
        {
          nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
        } ''
        cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
        tar -czf $out -C external-secrets .
      '';
  };

  # external-secrets =
  #   pkgs.runCommand "external-secrets.tgz"
  #   {
  #     nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
  #   } ''
  #     cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
  #     tar -czf $out -C external-secrets .
  #   '';
  manifests = {
    external-secrets-vault-store.content = {
      apiVersion = "external-secrets.io/v1beta1";
      kind = "ClusterSecretStore";
      metadata.name = "vault-cluster-store";
      spec = {
        provider.vault = {
          server = "https://${config.campground.services.k3s.vault-address}";
          path = lib.removeSuffix "/k3s" cfg.vault-path;
          version = config.campground.services.k3s.kvVersion;
          auth.appRole = {
            path = "approle";
            roleId.valueFrom.secretKeyRef = {
              name = "vault-auth";
              key = "role_id";
            };
            secretRef.secretId.secretKeyRef = {
              name = "vault-auth";
              key = "secret_id";
            };
          };
        };
      };
    };
    external-secrets.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata.name = "external-secrets";
      spec = {
        chart = "https://%{KUBERNETES_API}%/static/charts/external-secrets.tgz";
        targetNamespace = "external-secrets";
        createNamespace = true;
        helmVersion = "v3";
        insecureSkipTLSVerify = true;

        valuesContent = ''
          global:
            cacerts:
              skipVerify: true
          installCRDs: false
        '';
      };
    };

    # argocd = {
    #   source = pkgs.fetchurl {
    #     url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml";
    #     sha256 = "sha256-VJ3prz/xokTlDjnvUjA0eI7cJeJox74Sr89AHpTLyRY=";
    #   };
    # };
    # external-secrets-crds = {
    #   source = pkgs.fetchurl {
    #     url = "https://raw.githubusercontent.com/external-secrets/external-secrets/v0.16.1/deploy/crds/bundle.yaml";
    #     sha256 = "sha256-r0qcdMuiZqOqhNEwruZdi+NI3LUw4tkFan4pLjVU00U=";
    #   };
    # };
    public-traefik-routes = {
      content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "public-traefik-config";
          namespace = "kube-system";
        };
        data = {
          "dynamic.yaml" = lib.generators.toYAML { } config.campground.suites.public-hosting.dynamicConfigOptions;
        };
      };
    };
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
    package = lib.mkPackageOption pkgs "k3s" { };
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
      default = "10.8.0.197";
      description = "HA Proxy IP or K3s Server IP (used by agents).";
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
      inherit charts manifests;
      enable = true;
      package = cfg.package;
      clusterInit = cfg.clusterInit;
      role = cfg.role;
      tokenFile = mkIf (!cfg.clusterInit) "/var/lib/rancher/k3s/server/node-token";
      serverAddr = mkIf (!cfg.clusterInit) serverAddr;
      # autoDeployCharts = mkIf (cfg.role == "server") charts;
      configPath = mkIf (cfg.role == "server") (
        let
          configText = lib.generators.toYAML { } cfg.config;
        in
        pkgs.writeText "k3s-config.yaml" configText
      );
      moreFlags = cfg.extraFlags;
    };

    systemd.services.store-k3s-token = mkIf cfg.clusterInit {
      description = "Store K3s node-token and kubeconfig in Vault";
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

          until [ -f /var/lib/rancher/k3s/server/node-token ] && [ -f /etc/rancher/k3s/k3s.yaml ]; do
            sleep 5
          done

          echo "Reading K3s node-token and kubeconfig..."
          NODE_TOKEN=$(< /var/lib/rancher/k3s/server/node-token)
          KUBECONFIG_ORIG=$(cat /etc/rancher/k3s/k3s.yaml)

          # Replace 127.0.0.1 with your HAProxy IP

          # Replace 127.0.0.1 with server address
          HAPROXY_IP="${cfg.serverAddr}"
          KUBECONFIG_FIXED=$(echo "$KUBECONFIG_ORIG" | sed "s/127.0.0.1/$HAPROXY_IP/g")

          VAULT_PATH="${cfg.vault-path}"
          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID=$(cat /var/lib/vault/$HOSTNAME/role-id)
          SECRET_ID=$(cat /var/lib/vault/$HOSTNAME/secret-id)

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN=$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
          export VAULT_TOKEN

          echo "Storing K3s node-token and kubeconfig in Vault at $VAULT_PATH"
          ${pkgs.vault}/bin/vault kv put "$VAULT_PATH" \
            node_token="$NODE_TOKEN" \
            kubeconfig="$KUBECONFIG_FIXED"

          echo "Done storing K3s token and kubeconfig."
        '';
        RemainAfterExit = true;
      };
    };

    environment.systemPackages = [ cfg.package ];
    systemd.services.k3s.preStart = mkMerge [
      (mkIf (!cfg.clusterInit) (mkBefore ''
        mkdir -p /var/lib/rancher/k3s/server
        cp /tmp/detsys-vault/k3s-token /var/lib/rancher/k3s/server/node-token
      ''))

      (mkBefore ''
        ROLE_ID=$(< ${config.campground.services.vault-agent.settings.vault.role-id})
        SECRET_ID=$(< ${config.campground.services.vault-agent.settings.vault.secret-id})
        ${pkgs.envsubst}/bin/envsubst < ${external-secrets-yaml} > /var/lib/rancher/k3s/server/manifests/external-secrets-auth.yaml
      '')
    ];

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
