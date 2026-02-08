{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.cert-manager;
in {
  options.fmf.services.cert-manager = with types; {
    enable =
      mkEnableOption "Whether to enable the fetch-cert-manager-certs service.";

    certs = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          namespace = lib.mkOption {
            type = lib.types.str;
            description = "Kubernetes namespace where the certificate is located.";
          };
          tlsSecret = lib.mkOption {
            type = lib.types.str;
            description = "Name of the Kubernetes TLS Secret containing the certificate.";
          };
        };
      });
      default = [];
      description = "List of certs to fetch.";
    };
    cert-folder =
      mkOpt str "/var/lib/vault/certs/" "The place to store all certs on disk";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/k8s"
      "The Vault path to the KV containing the Kubeconfig.";
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
  };

  config = lib.mkIf cfg.enable {
    fmf.apps.k9s = {
      enable = true;
      role-id = cfg.role-id;
      secret-id = cfg.secret-id;
      vault-path = cfg.vault-path;
      kvVersion = cfg.kvVersion;
      vault-address = cfg.vault-address;
    };

    systemd.services = lib.listToAttrs (builtins.map (cert: {
        name = "fetchCertManagerCert-${cert.namespace}";
        value = {
          description = "Fetch certificates from cert-manager and store them";
          serviceConfig = {Type = "oneshot";};
          script = ''
            export KUBECONFIG=/etc/k8s/config

            mkdir -p ${cfg.cert-folder}

            # Fetch the certificates
            ${pkgs.kubectl}/bin/kubectl get secret ${cert.tlsSecret} -n ${cert.namespace} -o jsonpath="{.data.tls\.crt}" | base64 --decode > /var/lib/vault/certs/${cert.namespace}-${cert.tlsSecret}-tls.crt
            ${pkgs.kubectl}/bin/kubectl get secret ${cert.tlsSecret} -n ${cert.namespace} -o jsonpath="{.data.tls\.key}" | base64 --decode > /var/lib/vault/certs/${cert.namespace}-${cert.tlsSecret}-tls.key
          '';
        };
      })
      cfg.certs);

    systemd.timers = lib.listToAttrs (builtins.map (cert: {
        name = "fetchCertManagerCert-${cert.namespace}.timer";
        value = {
          description = "Timer to run fetchCertManagerCert-${cert.namespace} service";
          partOf = ["fetchCertManagerCert-${cert.namespace}.service"];
          timerConfig.OnCalendar = "daily";
          timerConfig.Persistent = true;
        };
      })
      cfg.certs);
  };
}
