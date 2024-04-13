{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.kubernetes;
  inherit (pkgs.campground) k0s;
in {
  options.campground.services.kubernetes = with types; {
    enable = mkBoolOpt false "Enable k0scontroller;";
    roles = mkOption {
      type = types.listOf (types.enum ["master" "node"]);
      default = "stable";
      description = "What type of role?";
    };
    kubeMasterHostname =
      mkOpt str "campnet" "The host name of the master node or your HA Proxy";
    kubeMasterAPIServerPort =
      mkOpt int 6443 "The port your master node or your HA Proxy listens on";
    kubeMasterIP =
      mkOpt str "10.8.0.1" "The IP of the master node or your HA Proxy";
    apiserverAddress =
      mkOpt str
      "https://${cfg.kubeMasterHostname}:${cfg.kubeMasterAPIServerPort}"
      "The API Server Address";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/kubernetes"
      "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [kompose kubectl kubernetes];
    security.apparmor.enable = true;

    services.kubernetes = {
      roles = cfg.roles;
      masterAddress = cfg.kubeMasterHostname;
      apiserverAddress = cfg.apiserverAddress;
      easyCerts = true;
      apiserver = {
        securePort = cfg.kubeMasterAPIServerPort;
        advertiseAddress = cfg.kubeMasterIP;
      };
      addons.dns.enable = true;

      kubelet.extraOpts = "--fail-swap-on=false";
    };

    systemd.services.UploadK8sAPIToken = {
      after = ["kubernetes.service"]; # Ensure it runs after Kubernetes
      requires = ["kubernetes.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root"; # Run as root, adjust if necessary
      };
      script = ''
        # Define your configuration variables
        roleID=$(cat ${cfg.role-id})
        secretID=$(cat ${cfg.secret-id})
        vaultPath=${cfg.vault-path}
        vaultAddress=${cfg.vault-address}

        # Export Vault address
        export VAULT_ADDR=$vaultAddress

        # Login to Vault using role-id and secret-id
        ${pkgs.vault}/bin/vault login -method=approle role_id="$roleID" secret_id="$secretID"

        # Path where you want to store your secrets in Vault
        vaultKvPath="$vaultPath/apitoken"

        # The file containing the secret you want to store
        secretFile="/var/lib/kubernetes/secrets/apitoken.secret"

        # Read the secret value
        secretValue=$(cat $secretFile)

        # Store the secret in Vault
        ${pkgs.vault}/bin/vault kv put $vaultKvPath secret="$secretValue"

        echo "Secret stored successfully in Vault at $vaultKvPath"
      '';
    };

    # campground.services.vault-agent.services.k0scontroller = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [{
    #         type = "approle";
    #         config = {
    #           role_id_file_path = cfg.role-id;
    #           secret_id_file_path = cfg.secret-id;
    #           remove_secret_id_file_after_reading = false;
    #         };
    #       }];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "controller-token" = {
    #           # text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.k0s }}{{ else }}{{ .Data.data.k0s }}{{ end }}{{ end }}'';
    #           text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.controller }}{{ else }}{{ .Data.data.controller }}{{ end }}{{ end }}'';
    #           permissions = "0600";  # Make the script executable
    #           change-action = "restart";
    #         };
    #         "k0s.yaml" = {
    #           text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.k0s }}{{ else }}{{ .Data.data.k0s }}{{ end }}{{ end }}'';
    #           permissions = "0600";  # Make the script executable
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
