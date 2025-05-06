{ lib
, config
, pkgs
, ...
}:
with lib; {
  options.campground.services.k3s.modules.certificates.enable = mkEnableOption "Deploy cert-manager and wildcard certificates";

  config = mkIf config.campground.services.k3s.modules.certificates.enable {
    services.k3s.manifests = {
      cert-manager = {
        source = pkgs.fetchurl {
          url = "https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml";
          sha256 = "sha256-2rJ5QXZinYBCzpe4hfN43+Tve1vtWFnp8GYW6tmYD0s=";
        };
      };

      cloudflare-clusterissuer.content = {
        apiVersion = "cert-manager.io/v1";
        kind = "ClusterIssuer";
        metadata.name = "cloudflare";
        spec.acme = {
          email = "cloudflare@aicampground.com";
          server = "https://acme-v02.api.letsencrypt.org/directory";
          privateKeySecretRef.name = "letsencrypt";
          solvers = [
            {
              dns01.cloudflare = {
                email = "cloudflare@aicampground.com";
                apiTokenSecretRef = {
                  name = "cloudflare-api-token-secret";
                  key = "api-token";
                };
              };
            }
          ];
        };
      };

      wildcard-matt-camp.content = {
        apiVersion = "cert-manager.io/v1";
        kind = "Certificate";
        metadata = {
          name = "wildcard-matt-camp-cert";
          namespace = "public-traefik";
        };
        spec = {
          secretName = "wildcard-matt-camp-tls";
          issuerRef = {
            name = "cloudflare";
            kind = "ClusterIssuer";
          };
          commonName = "matt-camp.com";
          dnsNames = [
            "matt-camp.com"
            "*.matt-camp.com"
          ];
        };
      };

      wildcard-aicampground-cert.content = {
        apiVersion = "cert-manager.io/v1";
        kind = "Certificate";
        metadata = {
          name = "wildcard-aicampground-cert";
          namespace = "public-traefik";
        };
        spec = {
          secretName = "wildcard-aicampground-tls";
          issuerRef = {
            name = "cloudflare";
            kind = "ClusterIssuer";
          };
          commonName = "aicampground.com";
          dnsNames = [
            "aicampground.com"
            "*.aicampground.com"
          ];
        };
      };
    };
  };
}
