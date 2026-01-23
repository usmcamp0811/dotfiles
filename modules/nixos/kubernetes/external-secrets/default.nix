{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.modules.external-secrets;

  # Split cfg.vault-path like "secret/campground/k3s"
  vaultPathParts = lib.splitString "/" cfg.vault-path;
  vaultMount = lib.head vaultPathParts; # e.g. "secret"
  vaultSubPath = lib.concatStringsSep "/" (lib.tail vaultPathParts); # e.g. "campground/k3s"

  # Vault wants an https://... URL for kubernetes_host
  k8sHostUrl = "https://${cfg.serverAddr}:6443";

  # Render a single ExternalSecret manifest from an item in cfg.externalSecrets
  renderExternalSecret = es: let
    # Defaults that keep the schema ergonomic
    name = es.name;
    namespace = es.namespace;
    targetName = if es.targetName == null then es.name else es.targetName;
    refreshInterval = es.refreshInterval;
    storeName = es.secretStoreRef.name;
    storeKind = es.secretStoreRef.kind;
    creationPolicy = es.target.creationPolicy;
    deletionPolicy = es.target.deletionPolicy;
    templateType = es.target.templateType;
    templateEngineVersion = es.target.templateEngineVersion;
    templateData = es.target.templateData;
    hasTemplateData = templateData != {};
    data = es.data;
    dataFromExtract = es.dataFromExtract;

    # data: [{ secretKey = "..."; remoteRef = { key = "..."; property = nullOr "..."; version = nullOr "..."; }; }]
    renderDataItem = item: let
      propLine =
        if item.remoteRef.property == null
        then ""
        else "\n        property: ${item.remoteRef.property}";
      verLine =
        if item.remoteRef.version == null
        then ""
        else "\n        version: ${item.remoteRef.version}";
    in ''
      - secretKey: ${item.secretKey}
        remoteRef:
          key: ${item.remoteRef.key}${propLine}${verLine}
    '';

    # dataFromExtract: [{ key = "..."; version = nullOr "..."; }]
    renderExtractItem = item: let
      verLine =
        if item.version == null
        then ""
        else "\n        version: ${item.version}";
    in ''
      - extract:
          key: ${item.key}${verLine}
    '';

    dataBlock =
      if data == []
      then ""
      else ''
        data:
${lib.concatStringsSep "" (map renderDataItem data)}
      '';

    dataFromBlock =
      if dataFromExtract == []
      then ""
      else ''
        dataFrom:
${lib.concatStringsSep "" (map renderExtractItem dataFromExtract)}
      '';

    templateBlock =
      if !hasTemplateData && templateType == null && templateEngineVersion == null
      then ""
      else ''
        template:
${optionalString (templateType != null) "          type: ${templateType}\n"}${optionalString (templateEngineVersion != null) "          engineVersion: ${templateEngineVersion}\n"}${optionalString hasTemplateData ''
          data:
${lib.concatStringsSep "" (lib.mapAttrsToList (k: v: "            ${k}: ${toString v}\n") templateData)}''}
      '';
  in ''
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${name}
      namespace: ${namespace}
    spec:
      refreshInterval: ${refreshInterval}
      secretStoreRef:
        name: ${storeName}
        kind: ${storeKind}
      target:
        name: ${targetName}
        creationPolicy: ${creationPolicy}
        deletionPolicy: ${deletionPolicy}
${templateBlock}${dataFromBlock}${dataBlock}
  '';

  # One YAML file containing all ExternalSecret objects, applied by the deploy job after CRDs exist.
  externalSecretsYaml =
    if cfg.externalSecrets == []
    then "# no ExternalSecrets configured\n"
    else (lib.concatStringsSep "\n---\n" (map renderExternalSecret cfg.externalSecrets)) + "\n";
in {
  options.fmf.services.k3s.modules.external-secrets = {
    enable = mkEnableOption "Deploy External Secrets and Vault Store";

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = "10.8.40.49";
      description = "HA Proxy IP or K3s Server IP (used by agents).";
    };

    vault-policy = mkOpt types.str "campground" "The Policy to give the `vault-auth` ServiceAccount";

    role-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";

    secret-id =
      mkOpt types.str
      config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";

    vault-path =
      mkOpt types.str "secret/campground/k3s"
      "Vault KV path used for your k3s secrets (also used to infer mount/path for ClusterSecretStore).";

    vault-address = mkOption {
      type = types.str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };

    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };

    # NEW: declarative ExternalSecret definitions applied by the same job that applies ClusterSecretStore
    externalSecrets = mkOption {
      type = types.listOf (types.submodule ({...}: {
        options = {
          name = mkOption {
            type = types.str;
            description = "ExternalSecret metadata.name";
          };

          namespace = mkOption {
            type = types.str;
            default = "external-secrets";
            description = "Namespace where this ExternalSecret (and its target Secret) will live.";
          };

          refreshInterval = mkOption {
            type = types.str;
            default = "1h";
            description = "ExternalSecret spec.refreshInterval (string duration).";
          };

          secretStoreRef = mkOption {
            type = types.submodule ({...}: {
              options = {
                name = mkOption {
                  type = types.str;
                  default = "vault-backend";
                  description = "Name of the SecretStore/ClusterSecretStore to reference.";
                };
                kind = mkOption {
                  type = types.enum ["ClusterSecretStore" "SecretStore"];
                  default = "ClusterSecretStore";
                  description = "Kind of store reference (ClusterSecretStore recommended).";
                };
              };
            });
            default = {};
            description = "spec.secretStoreRef";
          };

          targetName = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "If set, ExternalSecret spec.target.name; defaults to the ExternalSecret name.";
          };

          target = mkOption {
            type = types.submodule ({...}: {
              options = {
                creationPolicy = mkOption {
                  type = types.enum ["Owner" "Merge" "None"];
                  default = "Owner";
                  description = "ExternalSecret spec.target.creationPolicy";
                };
                deletionPolicy = mkOption {
                  type = types.enum ["Delete" "Retain" "Merge"];
                  default = "Retain";
                  description = "ExternalSecret spec.target.deletionPolicy";
                };

                # Optional template controls (kept lightweight; you can expand later if you want full template support)
                templateType = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "ExternalSecret spec.target.template.type (optional).";
                };
                templateEngineVersion = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "ExternalSecret spec.target.template.engineVersion (optional).";
                };
                templateData = mkOption {
                  type = types.attrs;
                  default = {};
                  description = "ExternalSecret spec.target.template.data (optional attrset, stringy values).";
                };
              };
            });
            default = {};
            description = "ExternalSecret spec.target options";
          };

          # Either do explicit key mapping...
          data = mkOption {
            type = types.listOf (types.submodule ({...}: {
              options = {
                secretKey = mkOption {
                  type = types.str;
                  description = "Key in the resulting Kubernetes Secret (spec.data[].secretKey).";
                };
                remoteRef = mkOption {
                  type = types.submodule ({...}: {
                    options = {
                      key = mkOption {
                        type = types.str;
                        description = "Vault key path relative to the store mount/path (spec.data[].remoteRef.key).";
                      };
                      property = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "Optional property for JSON/structured secrets (spec.data[].remoteRef.property).";
                      };
                      version = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "Optional version (kv v2) (spec.data[].remoteRef.version).";
                      };
                    };
                  });
                  description = "Remote ref configuration.";
                };
              };
            }));
            default = [];
            description = "ExternalSecret spec.data (explicit key mapping).";
          };

          # ...or extract an entire object into the Secret
          dataFromExtract = mkOption {
            type = types.listOf (types.submodule ({...}: {
              options = {
                key = mkOption {
                  type = types.str;
                  description = "Vault key to extract (spec.dataFrom[].extract.key).";
                };
                version = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Optional version (kv v2) (spec.dataFrom[].extract.version).";
                };
              };
            }));
            default = [];
            description = "ExternalSecret spec.dataFrom with extract (bulk import).";
          };
        };
      }));
      default = [];
      description = ''
        Declarative ExternalSecret objects. These are applied by a Job after the external-secrets CRDs exist
        (same anti-race approach as the ClusterSecretStore apply).
      '';
      example = literalExpression ''
        [
          {
            name = "postgres-creds";
            namespace = "default";
            refreshInterval = "15m";
            secretStoreRef = { name = "vault-backend"; kind = "ClusterSecretStore"; };
            targetName = "postgres-creds";
            data = [
              { secretKey = "username"; remoteRef = { key = "campground/k3s/postgres"; property = "username"; }; }
              { secretKey = "password"; remoteRef = { key = "campground/k3s/postgres"; property = "password"; }; }
            ];
          }
          {
            name = "app-config";
            namespace = "default";
            dataFromExtract = [
              { key = "campground/k3s/my-app/config"; }
            ];
          }
        ]
      '';
    };
  };

  config = mkIf cfg.enable {
    fmf.services.k3s.modules.certificates.enable = true;

    services.k3s.charts.external-secrets =
      pkgs.runCommand "external-secrets.tgz"
      { nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ]; } ''
        cp -r ${pkgs.nixhelmCharts.external-secrets.external-secrets} external-secrets
        tar -czf $out -C external-secrets .
      '';

    systemd.services.vault-k8s-init = mkIf (config.services.k3s.clusterInit) {
      description = "Configure Vault Kubernetes Auth";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "k3s.service"];
      wants = ["network-online.target"];
      requires = ["k3s.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "vault-k8s-init" ''
          set -euo pipefail

          NS=external-secrets
          SA=vault-auth

          export VAULT_ADDR="${cfg.vault-address}"
          HOSTNAME=${config.networking.hostName}

          ROLE_ID="$(cat /var/lib/vault/$HOSTNAME/role-id)"
          SECRET_ID="$(cat /var/lib/vault/$HOSTNAME/secret-id)"

          echo "Logging in to Vault using AppRole..."
          VAULT_TOKEN="$(${pkgs.vault}/bin/vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")"
          export VAULT_TOKEN

          echo "Waiting for namespace $NS to exist..."
          for i in $(seq 1 120); do
            if ${pkgs.k3s}/bin/k3s kubectl get ns "$NS" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          echo "Waiting for serviceaccount $NS/$SA to exist..."
          for i in $(seq 1 120); do
            if ${pkgs.k3s}/bin/k3s kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          echo "Creating token for $NS/$SA..."
          ${pkgs.k3s}/bin/k3s kubectl -n "$NS" create token "$SA" --duration=24h > /tmp/token.jwt

          echo "Reading cluster CA..."
          ${pkgs.k3s}/bin/k3s kubectl -n "$NS" get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/ca.crt

          echo "Configuring Vault Kubernetes auth..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/config \
            token_reviewer_jwt="$(< /tmp/token.jwt)" \
            kubernetes_host="${k8sHostUrl}" \
            kubernetes_ca_cert="$(< /tmp/ca.crt)"

          echo "Writing Vault Kubernetes role external-secrets..."
          ${pkgs.vault}/bin/vault write auth/kubernetes/role/external-secrets \
            bound_service_account_names="$SA" \
            bound_service_account_namespaces="*" \
            policies="${cfg.vault-policy}" \
            ttl=24h

          rm -f /tmp/token.jwt /tmp/ca.crt
        '';
        RemainAfterExit = true;
      };
    };

    # SystemD service to deploy ClusterSecretStore and ExternalSecrets after CRDs are ready
    systemd.services.external-secrets-deploy = {
      description = "Deploy ClusterSecretStore and ExternalSecrets";
      wantedBy = ["multi-user.target"];
      after = ["k3s.service" "vault-k8s-init.service"];
      wants = ["vault-k8s-init.service"];
      requires = ["k3s.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "external-secrets-deploy" ''
          set -euo pipefail

          echo "Waiting for k3s API server to be ready..."
          until ${pkgs.k3s}/bin/k3s kubectl get --raw /healthz >/dev/null 2>&1; do
            echo "k3s API not ready, waiting..."
            sleep 5
          done

          echo "Waiting for ClusterSecretStore CRD..."
          until ${pkgs.k3s}/bin/k3s kubectl get crd clustersecretstores.external-secrets.io >/dev/null 2>&1; do
            echo "clustersecretstores CRD not ready, waiting..."
            sleep 5
          done

          echo "Waiting for ExternalSecret CRD..."
          until ${pkgs.k3s}/bin/k3s kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; do
            echo "externalsecrets CRD not ready, waiting..."
            sleep 5
          done

          echo "CRDs are ready. Applying ClusterSecretStore..."
          cat <<EOF | ${pkgs.k3s}/bin/k3s kubectl apply -f -
          apiVersion: external-secrets.io/v1beta1
          kind: ClusterSecretStore
          metadata:
            name: vault-backend
          spec:
            provider:
              vault:
                server: ${cfg.vault-address}
                path: ${vaultMount}
                version: ${cfg.kvVersion}
                auth:
                  kubernetes:
                    mountPath: kubernetes
                    role: external-secrets
                    serviceAccountRef:
                      name: vault-auth
                      namespace: external-secrets
          EOF

          echo "ClusterSecretStore applied successfully."

          # Apply ExternalSecrets if any are configured
          if [ -n "${externalSecretsYaml}" ] && [ "${externalSecretsYaml}" != "# no ExternalSecrets configured"* ]; then
            echo "Applying ExternalSecrets..."
            cat <<'EOFES' | ${pkgs.k3s}/bin/k3s kubectl apply -f -
          ${externalSecretsYaml}
          EOFES
            echo "ExternalSecrets applied successfully!"
          else
            echo "No ExternalSecrets configured, skipping."
          fi

          echo "External secrets deployment complete."
        '';
        RemainAfterExit = true;
      };
    };

    services.k3s.manifests = {
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
            installCRDs: true
          '';
        };
      };

      vault-auth-sa.content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "vault-auth";
          namespace = "external-secrets";
        };
        automountServiceAccountToken = true;
      };

    };
  };
}
