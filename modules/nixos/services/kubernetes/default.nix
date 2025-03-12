{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.kubernetes;
in {
  options.campground.services.kubernetes = with types; {
    enable = mkBoolOpt false "Enable Kubernetes cluster.";
    haMode = mkBoolOpt false "Enable high availability mode.";
    roles = mkOption {
      type = listOf (enum [ "master" "node" ]);
      default = [ "node" ];
      description = "The role of the node in the cluster.";
    };
    kubeMasterHostname =
      mkOpt str "haproxy" "The hostname of the HAProxy server.";
    kubeMasterAPIServerPort =
      mkOpt int 6443 "The port HAProxy listens on for the Kubernetes API.";
    kubeMasterIPs = mkOption {
      type = listOf str;
      default = [ "10.8.0.1" ];
      description = "List of actual Kubernetes master node IPs.";
    };
    apiserverAddress = mkOption {
      type = str;
      default = "https://${cfg.kubeMasterHostname}:${
          toString cfg.kubeMasterAPIServerPort
        }";
      description = "The Kubernetes API server address.";
    };

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/kubernetes"
      "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ kompose kubectl kubernetes ];
    security.apparmor.enable = true;

    services.kubernetes = {
      roles = cfg.roles;
      masterAddress = cfg.kubeMasterHostname;
      apiserverAddress = cfg.apiserverAddress;
      easyCerts = true;
      apiserver = {
        securePort = cfg.kubeMasterAPIServerPort;
        advertiseAddress = builtins.elemAt cfg.kubeMasterIPs
          0; # First master IP used for advertising
      };
      addons.dns.enable = true;

      kubelet.extraOpts = "--fail-swap-on=false";
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
    #           text = ''
    #             {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.controller }}{{ else }}{{ .Data.data.controller }}{{ end }}{{ end }}'';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #         "k0s.yaml" = {
    #           text = ''
    #             {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.k0s }}{{ else }}{{ .Data.data.k0s }}{{ end }}{{ end }}'';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };

    # Enable HAProxy for HA mode
    campground.services.haproxy = mkIf cfg.haMode {
      enable = true;
      frontend-ip = "*";
      frontend-port = toString cfg.kubeMasterAPIServerPort;
      backendServers = builtins.listToAttrs (map
        (ip: {
          name = ip;
          value = { port = cfg.kubeMasterAPIServerPort; };
        })
        cfg.kubeMasterIPs);
    };
  };
}
