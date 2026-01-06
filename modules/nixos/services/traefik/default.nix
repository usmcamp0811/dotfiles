{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.traefik;

  jsonValue = with types; let
    valueType =
      nullOr
      (oneOf [
        bool
        int
        float
        str
        (lazyAttrsOf valueType)
        (listOf valueType)
      ])
      // {
        description = "JSON value";
        emptyValue.value = {};
      };
  in
    valueType;

  # Where Traefik expects plugins in "local mode" (relative to WorkingDirectory)
  pluginsRoot = "/var/lib/traefik/plugins-local/src";

  # Helper: only fetch when enabled + all fields present
  mkPluginSrc = pluginCfg:
    pkgs.fetchFromGitHub {
      owner = pluginCfg.owner;
      repo = pluginCfg.repo;
      rev = pluginCfg.rev;
      hash = pluginCfg.hash;
    };

  cloudflarewarpSrc =
    mkIf cfg.localPlugins.cloudflarewarp.enable (mkPluginSrc cfg.localPlugins.cloudflarewarp);

  fail2banSrc =
    mkIf cfg.localPlugins.fail2ban.enable (mkPluginSrc cfg.localPlugins.fail2ban);

  saveCert2Vault = pkgs.writeShellScriptBin "save-certs" ''
    ACME_JSON="${cfg.acme-path}"
    VAULT_BASE_PATH="${cfg.vault-path}"

    ROLE_ID=$(cat "${cfg.role-id}")
    SECRET_ID=$(cat "${cfg.secret-id}")
    export VAULT_ADDR="${cfg.vault-address}"
    export VAULT_TOKEN=$(${pkgs.curl}/bin/curl -s --request POST --data '{"role_id":"'$ROLE_ID'","secret_id":"'$SECRET_ID'"}' "$VAULT_ADDR/v1/auth/approle/login" | ${pkgs.jq}/bin/jq -r '.auth.client_token')

    if [[ ! -f "$ACME_JSON" ]]; then
      echo "Error: $ACME_JSON not found."
      exit 1
    fi

    certificates=$(${pkgs.jq}/bin/jq -c '.cloudflare.Certificates[]' "$ACME_JSON")
    if [[ -z "$certificates" ]]; then
      echo "Error: No certificates found in $ACME_JSON."
      exit 1
    fi

    while IFS= read -r cert_entry; do
      domain=$(echo "$cert_entry" | ${pkgs.jq}/bin/jq -r '.domain.main')
      cert=$(echo "$cert_entry" | ${pkgs.jq}/bin/jq -r '.certificate')
      key=$(echo "$cert_entry" | ${pkgs.jq}/bin/jq -r '.key')

      if [[ -z "$domain" || -z "$cert" || -z "$key" ]]; then
        echo "Warning: Incomplete data for a certificate, skipping."
        continue
      fi

      vault_path="$VAULT_BASE_PATH/$domain"
      echo "Saving certificate for $domain to Vault at $vault_path..."

      echo "$cert" | base64 -d > cert.pem
      echo "$key" | base64 -d > key.pem
      ${pkgs.vault-bin}/bin/vault kv put "$vault_path" cert=@cert.pem key=@key.pem

      if [[ $? -ne 0 ]]; then
        echo "Error: Failed to save certificate for $domain."
      else
        echo "Certificate for $domain saved successfully."
      fi

      rm -f cert.pem key.pem
    done <<< "$certificates"

    echo "All certificates processed."
  '';
in {
  options.fmf.services.traefik = with types; {
    enable = mkBoolOpt false "Enable Traefik";
    email = mkOpt str config.fmf.user.email "The email to use.";
    docker-provider = mkBoolOpt false "Whether or not to enable Docker provider exposedByDefault.";
    acme-path =
      mkOpt str "/var/lib/traefik/acme.json"
      "The location Traefik saves the certs";
    domains = mkOption {
      type = listOf str;
      default = ["aicampground.com"];
      example = ["example.com" "example.org"];
      description = "List of domains.";
    };
    log-path =
      mkOpt str "/var/lib/traefik/access.log"
      "The location to store the access log.";
    insecure = mkBoolOpt false "Insecure dashboard?";
    dynamicConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "HTTP configuration for routers and services";
    };
    entrypoints = mkOption {
      type = jsonValue;
      default = {web = {address = "0.0.0.0:80";};};
      example = {web = {address = "0.0.0.0:80";};};
      description = "List of entrypoints for Traefik, mapping names to their address.";
    };

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/cloudflare"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };

    # Local-mode plugin pinning (prevents nixpkgs Traefik derivation from trying to vendor plugins into $out)
    localPlugins = mkOption {
      type = types.submodule {
        options = {
          cloudflarewarp = mkOption {
            type = types.submodule {
              options = {
                enable = mkBoolOpt true "Enable cloudflarewarp local plugin (local mode).";
                owner = mkOpt str "fma965" "GitHub owner.";
                repo = mkOpt str "cloudflarewarp" "GitHub repo.";
                rev = mkOpt str "" "Git revision (commit or tag).";
                hash = mkOpt str "" "Nix sha256 for fetchFromGitHub.";
                moduleName = mkOpt str "github.com/fma965/cloudflarewarp" "Traefik moduleName.";
              };
            };
            default = {};
            description = "cloudflarewarp plugin source pin.";
          };

          fail2ban = mkOption {
            type = types.submodule {
              options = {
                enable = mkBoolOpt true "Enable fail2ban local plugin (local mode).";
                owner = mkOpt str "tomMoulard" "GitHub owner.";
                repo = mkOpt str "fail2ban" "GitHub repo.";
                rev = mkOpt str "" "Git revision (commit or tag).";
                hash = mkOpt str "" "Nix sha256 for fetchFromGitHub.";
                moduleName = mkOpt str "github.com/tomMoulard/fail2ban" "Traefik moduleName.";
              };
            };
            default = {};
            description = "fail2ban plugin source pin.";
          };
        };
      };
      default = {};
      description = ''
        Configure Traefik experimental.localPlugins using "local mode" by placing plugin sources at:
          /var/lib/traefik/plugins-local/src/<moduleName>
        This avoids rebuilding the Traefik derivation with vendored plugins.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jq
      curl
      vault-bin
    ];

    # Force the stock Traefik package so nixpkgs doesn't try to vendor local plugins into $out/bin
    services.traefik.package = mkForce pkgs.traefik;

    # Ensure Traefik runs from /var/lib/traefik so ./plugins-local is discovered
    systemd.services.traefik.serviceConfig = {
      Restart = mkDefault "always";
      RestartSec = 5;

      WorkingDirectory = "/var/lib/traefik";
      ReadWritePaths = ["/var/lib/traefik"];
    };

    # Create local plugin workspace + symlink pinned sources into the exact Go module paths
    systemd.tmpfiles.rules = let
      mkPluginRules = pluginCfg: src: [
        "d ${pluginsRoot} 0755 traefik traefik - -"
        "d ${pluginsRoot}/github.com 0755 traefik traefik - -"
        "d ${pluginsRoot}/github.com/${pluginCfg.owner} 0755 traefik traefik - -"
        "L+ ${pluginsRoot}/github.com/${pluginCfg.owner}/${pluginCfg.repo} - - - - ${src}"
      ];

      cloudflareRules =
        if cfg.localPlugins.cloudflarewarp.enable && cfg.localPlugins.cloudflarewarp.rev != "" && cfg.localPlugins.cloudflarewarp.hash != ""
        then mkPluginRules cfg.localPlugins.cloudflarewarp cloudflarewarpSrc
        else [];

      fail2banRules =
        if cfg.localPlugins.fail2ban.enable && cfg.localPlugins.fail2ban.rev != "" && cfg.localPlugins.fail2ban.hash != ""
        then mkPluginRules cfg.localPlugins.fail2ban fail2banSrc
        else [];
    in
      cloudflareRules ++ fail2banRules;

    users.users.traefik = {extraGroups = ["docker"];};

    services.traefik = {
      enable = true;

      dynamicConfigOptions = cfg.dynamicConfigOptions;

      staticConfigOptions = {
        experimental.localPlugins =
          (optionalAttrs (cfg.localPlugins.cloudflarewarp.enable) {
            cloudflarewarp.moduleName = cfg.localPlugins.cloudflarewarp.moduleName;
          })
          // (optionalAttrs (cfg.localPlugins.fail2ban.enable) {
            fail2ban.moduleName = cfg.localPlugins.fail2ban.moduleName;
          });

        serversTransport = {
          insecureSkipVerify = false;
          maxIdleConnsPerHost = 200;
          rootCAs = [];
          forwardingTimeouts = {
            dialTimeout = "30s";
            responseHeaderTimeout = "0s";
            idleConnTimeout = "1800s";
          };
        };

        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        log = {
          level = "INFO";
          format = "json";
        };

        accessLog = {
          filePath = cfg.log-path;
          format = "json";
        };

        entryPoints =
          {
            web = {
              transport = {
                respondingTimeouts = {
                  readTimeout = "0s";
                  writeTimeout = "0s";
                  idleTimeout = "1800s";
                };
              };
              http.redirections.entryPoint = {
                to = "websecure";
                scheme = "https";
                permanent = true;
              };
            };
            websecure = {
              transport = {
                respondingTimeouts = {
                  readTimeout = "0s";
                  writeTimeout = "0s";
                  idleTimeout = "1800s";
                };
              };
              address = "0.0.0.0:443";
              forwardedHeaders = {
                trustedIPs = [
                  "173.245.48.0/20"
                  "103.21.244.0/22"
                  "103.22.200.0/22"
                  "103.31.4.0/22"
                  "141.101.64.0/18"
                  "108.162.192.0/18"
                  "190.93.240.0/20"
                  "188.114.96.0/20"
                  "197.234.240.0/22"
                  "198.41.128.0/17"
                  "162.158.0.0/15"
                  "104.16.0.0/13"
                  "104.24.0.0/14"
                  "172.64.0.0/13"
                  "131.0.72.0/22"
                ];
              };
              http.tls = {
                certResolver = "cloudflare";
                domains =
                  map
                  (domain: {
                    main = domain;
                    sans = ["*.${domain}" "*.lan.${domain}"];
                  })
                  cfg.domains;
              };
            };
          }
          // cfg.entrypoints;

        api = {
          dashboard = true;
          insecure = cfg.insecure;
        };

        certificatesResolvers.cloudflare.acme = {
          email = cfg.email;
          storage = "${cfg.acme-path}";
          dnsChallenge = {
            provider = "cloudflare";
            resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
          };
        };

        providers.docker.exposedByDefault = cfg.docker-provider;

        metrics.prometheus = {
          entryPoint = "metrics";
          addEntryPointsLabels = true;
          addServicesLabels = true;
        };
      };
    };

    systemd.services.saveCertsToVault = {
      description = "Save TLS Certs in Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "/var/lib/traefik";
        ReadWritePaths = ["/var/lib/traefik"];
      };
      script = ''
        while [[ ! -f ${cfg.acme-path} ]]; do sleep 1; done && ${saveCert2Vault}/bin/save-certs
      '';
      wantedBy = ["multi-user.target"];
      after = ["traefik.service"];
    };

    fmf.services.vault-agent.services."traefik" = {
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

      secrets.environment.templates = {
        traefik = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            CF_DNS_API_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'
            CLOUDFLARE_DNS_API_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
