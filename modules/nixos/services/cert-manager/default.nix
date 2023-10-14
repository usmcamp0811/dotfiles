{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.services.fetchCertManagerCerts;
in
{
  options.campground.services.fetchCertManagerCerts = with types; {
    enable = mkBolOpt false "Whether to enable the fetch-cert-manager-certs service.";

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
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.listToAttrs (lib.mapAttrsToList (name: cert: {
      name = "fetchCertManagerCert-${name}";
      value = {
        description = "Fetch certificates from cert-manager and store them";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          # Fetch the certificates
          kubectl get secret ${cert.tlsSecret} -n ${cert.namespace} -o jsonpath="{.data.tls\.crt}" | base64 --decode > /var/lib/vault/certs/${cert.namespace}-${cert.tlsSecret}-tls.crt
          kubectl get secret ${cert.tlsSecret} -n ${cert.namespace} -o jsonpath="{.data.tls\.key}" | base64 --decode > /var/lib/vault/certs/${cert.namespace}-${cert.tlsSecret}-tls.key
        '';
      };
    }) (lib.flip lib.listToAttrs (builtins.attrNames cfg.certs)) cfg.certs);

    systemd.timers = lib.listToAttrs (lib.mapAttrsToList (name: cert: {
      name = "fetchCertManagerCert-${name}.timer";
      value = {
        description = "Timer to run fetchCertManagerCert-${name} service";
        partOf = [ "fetchCertManagerCert-${name}.service" ];
        timerConfig.OnCalendar = "daily";  # Run daily
        timerConfig.Persistent = true;  # Run at the next boot if the timer elapses while the system is off
      };
    }) (lib.flip lib.listToAttrs (builtins.attrNames cfg.certs)) cfg.certs);
  };
}
