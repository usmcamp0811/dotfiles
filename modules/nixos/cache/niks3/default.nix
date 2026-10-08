{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cache.niks3;
  mtls = cfg.mtls;

  host = config.networking.hostName;

  # The oneshot below has the same name as its vault-agent sidecar, so
  # nixos-vault-service "infects" it (it joins the sidecar's namespace, where the
  # rendered files live under /tmp/detsys-vault/). Same pattern as
  # fmf.services.nix-grpc-store.
  certsUnit = "niks3-pull-certs";
  renderedFile = "/tmp/detsys-vault/pull.pem";
  keyMarker = "#--KEY--";

  # Upper bound on waiting for Vault-rendered secrets, so a Vault problem can
  # never hold up boot or a switch.
  startTimeout = "60s";

  # The default location of the public CA certificate (the Vault PKI mount that
  # signs niks3's server certificate). It is public, not a secret, so it lives
  # in the repo. Create it with:
  #   vault read -field=certificate grpc-farm-pki/cert/ca > farm-ca.pem
  defaultCaFile = ./farm-ca.pem;
  haveDefaultCa = builtins.pathExists defaultCaFile;

  # MicroVMs keep the anonymous LAN path (one Vault cert per VM isn't worth it).
  isVm = hasPrefix "vm-" config.networking.hostName;
  hasVaultAgent = config.fmf.services.vault-agent.enable;

  # niks3's server certificate comes from a private CA, but Nix's `ssl-cert-file`
  # is global to the nix daemon (cache.nixos.org etc.), so it must hold the
  # private CA AND the normal roots. Built at evaluation time from a store path,
  # so it can never be missing at boot (a missing ssl-cert-file would break every
  # download, not just this cache).
  caBundle = pkgs.runCommand "niks3-ca-bundle.pem" {} ''
    cat ${mtls.caFile} ${config.security.pki.caBundle} > $out
  '';

  # Nix >= 2.34 takes the client certificate as per-store settings.
  mtlsUrl = "${mtls.url}?tls-certificate=${mtls.certDir}/client.crt&tls-private-key=${mtls.certDir}/client.key";

  substituterUrl =
    if mtls.enable
    then mtlsUrl
    else cfg.url;

  vaultAgentSettings = {
    vault.address = mtls.vault-address;

    auto_auth = {
      method = [
        {
          type = "approle";

          config = {
            role_id_file_path = mtls.role-id;
            secret_id_file_path = mtls.secret-id;
            remove_secret_id_file_after_reading = false;
          };
        }
      ];
    };
  };

  certsScript = ''
    set -euo pipefail
    umask 077
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT

    in="${renderedFile}"
    if [ ! -s "$in" ]; then
      echo "niks3-pull-certs: no certificate rendered by vault-agent yet" >&2
      exit 1
    fi

    awk -v cert="$work/leaf" -v key="$work/key" '
      BEGIN { out = cert }
      $0 == "${keyMarker}" { out = key; next }
      { print > out }
    ' "$in"

    # Never install a mismatched pair.
    if [ "$(openssl x509 -noout -pubkey -in "$work/leaf")" != "$(openssl pkey -pubout -in "$work/key")" ]; then
      echo "niks3-pull-certs: certificate and private key do not match, not installing" >&2
      exit 1
    fi

    # And never install a certificate our (build-time) CA does not vouch for:
    # that would mean the CA baked into this configuration is stale.
    if ! openssl verify -CAfile ${mtls.caFile} "$work/leaf" >/dev/null 2>&1; then
      echo "niks3-pull-certs: issued certificate does not verify against ${mtls.caFile}; not installing (is fmf.cache.niks3.mtls.caFile current?)" >&2
      openssl verify -CAfile ${mtls.caFile} "$work/leaf" >&2 || true
      exit 1
    fi

    install -d -m 0755 ${mtls.certDir}
    install -m 0644 -o root -g root "$work/leaf" ${mtls.certDir}/client.crt.new
    install -m 0600 -o root -g root "$work/key"  ${mtls.certDir}/client.key.new
    # key first, then certificate: a reader never sees a new cert with an old key
    mv -f ${mtls.certDir}/client.key.new ${mtls.certDir}/client.key
    mv -f ${mtls.certDir}/client.crt.new ${mtls.certDir}/client.crt
    echo "niks3-pull-certs: installed $(openssl x509 -noout -subject -enddate -in "$work/leaf" | tr '\n' ' ')"
  '';
in {
  options.fmf.cache.niks3 = with types; {
    enable = mkEnableOption "Campground niks3 binary cache (LAN)";

    url =
      mkOpt str "https://niks3.lan.aicampground.com"
      "URL of the niks3 cache. Reads are served by niks3's read proxy, so this one URL is all clients need.";

    publicKey =
      mkOpt (nullOr str) "reckless-niks3-1:ithnB9sIBPvw6J8XfdTjwLhk7zOQYGhaEXz4ZGfA7oc="
      ''
        Public half of niks3's narinfo signing key (the Vault "sign_key"
        secret), in "name:base64" form. Produce it from the secret key with
        `nix key convert-secret-to-public`. Until this is set the substituter
        is NOT added (Nix would reject every path without a trusted key) and
        a warning is emitted.
      '';

    mtls = {
      enable =
        mkOpt bool (!isVm && hasVaultAgent && haveDefaultCa)
        ''
          Pull from the internet-facing, client-certificate-gated endpoint
          (`mtls.url`) instead of `url`. vault-agent issues this host a
          read-only certificate (CN niks3-pull-<hostname>) from Vault PKI, a
          oneshot installs it under `mtls.certDir`, and Nix is given the
          substituter URL with `tls-certificate` / `tls-private-key` (Nix >=
          2.34). Use this for hosts that are not on the trusted LAN, where
          `url` is reachable without credentials. Needs
          fmf.services.vault-agent.

          Also sets the (global) `ssl-cert-file` to a bundle of the private CA
          and the system roots.

          Defaults to on for physical hosts (hostname not `vm-*`) that run
          vault-agent, once the public CA file exists (see `caFile`); off
          otherwise, so a flake without that file is unaffected.
        '';

      url =
        mkOpt str "https://niks3.aicampground.com"
        "Client-certificate-gated niks3 endpoint.";

      caFile =
        mkOpt (nullOr path) (
          if builtins.pathExists defaultCaFile
          then defaultCaFile
          else null
        )
        ''
          Public CA certificate (PEM) that signs both niks3's server certificate
          and the pull certificates. Defaults to ./farm-ca.pem next to this
          module if that file exists (it must be `git add`ed). Create it with
          `vault read -field=certificate grpc-farm-pki/cert/ca`.
        '';

      certDir =
        mkOpt str "/var/lib/niks3-pull"
        "Where the issued client certificate and key are installed.";

      pki = {
        path =
          mkOpt str "grpc-farm-pki/issue/niks3-pull-client"
          "Vault PKI issue path (mount/issue/role) for the read-only client certificate.";

        ttl =
          mkOpt str "720h"
          "Certificate lifetime. vault-agent renews it at ~90% of this, so keep it long enough to ride out a Vault outage.";
      };

      role-id =
        mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id.";

      secret-id =
        mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id.";

      vault-address = mkOption {
        type = str;
        default = config.fmf.services.vault-agent.settings.vault.address;
        description = "Vault server address.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      warnings =
        optional (!isVm && hasVaultAgent && !mtls.enable && mtls.caFile == null) ''
          fmf.cache.niks3: client-certificate pulls are NOT enabled on ${host}: the public CA file
          modules/nixos/cache/niks3/farm-ca.pem is missing (or not `git add`ed). Create it with:
            vault read -field=certificate grpc-farm-pki/cert/ca > modules/nixos/cache/niks3/farm-ca.pem
        ''
        ++ optional (cfg.publicKey == null) ''
        fmf.cache.niks3 is enabled but fmf.cache.niks3.publicKey is not set, so
        ${substituterUrl} is not being used as a substituter. Set publicKey to the
        public half of niks3's signing key (`nix key convert-secret-to-public`).
      '';
    }

    (mkIf (cfg.publicKey != null) {
      fmf.nix.extra-substituters.${substituterUrl}.key = cfg.publicKey;
    })

    (mkIf mtls.enable {
      assertions = [
        {
          assertion = mtls.caFile != null;
          message = "fmf.cache.niks3.mtls needs fmf.cache.niks3.mtls.caFile (the public Vault PKI CA). Create modules/nixos/cache/niks3/farm-ca.pem (and git add it) with: vault read -field=certificate grpc-farm-pki/cert/ca";
        }
        {
          assertion = config.fmf.services.vault-agent.enable;
          message = "fmf.cache.niks3.mtls needs fmf.services.vault-agent.enable = true (the client certificate is issued through Vault).";
        }
      ];

      nix.settings.ssl-cert-file = "${caBundle}";

      systemd.services.${certsUnit} = {
        description = "Install the niks3 pull client certificate issued by Vault PKI";
        wantedBy = ["multi-user.target"];
        path = [pkgs.openssl pkgs.gawk pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Bounded: one stuck secret must never hold up boot or a switch.
          TimeoutStartSec = startTimeout;
        };
        script = certsScript;
      };

      # The sidecar only reports ready once every monitored file is rendered.
      systemd.services."detsys-vaultAgent-${certsUnit}".serviceConfig.TimeoutStartSec = startTimeout;

      fmf.services.vault-agent.services.${certsUnit} = {
        settings = vaultAgentSettings;

        # A renewed certificate re-renders the file, which restarts the oneshot
        # (= reinstalls); nix reads the files on each connection.
        secrets.file = {
          change-action = "restart";
          files."pull.pem".text = ''
            {{ with pkiCert "${mtls.pki.path}" "common_name=niks3-pull-${host}" "ttl=${mtls.pki.ttl}" }}{{ .Cert }}${keyMarker}
            {{ .Key }}{{ end }}
          '';
        };
      };
    })
  ]);
}
