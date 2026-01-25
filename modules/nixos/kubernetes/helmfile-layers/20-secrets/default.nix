{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers."20-secrets";

  # Use the vault-k8s-init script directly from the package
  vaultInitScript = pkgs.fmf.vault-k8s-init.script;
in {
  options.fmf.services.k3s.helmfile.layers."20-secrets" = {
    enable = mkEnableOption "Deploy secrets layer (Vault integration, ClusterSecretStore)";

    vaultAddress = mkOption {
      type = types.str;
      example = "http://10.8.0.3:8200";
      description = "Vault server address";
    };

    vaultKvPath = mkOption {
      type = types.str;
      default = "secret/campground/k3s";
      description = "Vault KV path for Kubernetes secrets";
    };

    vaultKvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV version";
    };
  };

  config = mkIf cfg.enable {
    # Ensure controllers layer is enabled
    fmf.services.k3s.helmfile.layers."10-controllers".enable = true;

    # Disable the old external-secrets module to avoid conflicts
    fmf.services.k3s.modules.external-secrets.enable = lib.mkForce false;

    # The Vault init runs as a systemd oneshot service BEFORE helmfile
    # This ensures ClusterSecretStore exists before any releases that need it
    # Runs directly on the host with access to Vault AppRole credentials
    systemd.services.vault-k8s-init = mkIf config.services.k3s.clusterInit {
      description = "Initialize Vault Kubernetes Auth and ClusterSecretStore";
      after = ["k3s.service" "network-online.target"];
      requires = ["k3s.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "VAULT_ADDR=${cfg.vaultAddress}"
          "VAULT_KV_PATH=${cfg.vaultKvPath}"
          "VAULT_KV_VERSION=${cfg.vaultKvVersion}"
          "VAULT_POLICY=campground"
          "HOSTNAME=${config.networking.hostName}"
        ];
        ExecStart = "${vaultInitScript}/bin/vault-k8s-init";
      };

      # Only run on control plane nodes
      unitConfig.ConditionPathExists = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}
