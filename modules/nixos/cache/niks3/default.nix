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
  renderedMountCa = "/tmp/detsys-vault/pull-ca.pem";
  certMarker = "#--CERT--";
  keyMarker = "#--KEY--";

  # Upper bound on waiting for Vault-rendered secrets, so a Vault problem can
  # never hold up boot or a switch.
  startTimeout = "60s";

  # MicroVMs keep the anonymous LAN path (one Vault cert per VM isn't worth it).
  isVm = hasPrefix "vm-" config.networking.hostName;
  hasVaultAgent = config.fmf.services.vault-agent.enable;

  # The PKI mount, derived from the issue path ("<mount>/issue/<role>"), and
  # where its CA certificate is read from (public; not a secret).
  pkiMount = head (splitString "/issue/" mtls.pki.path);
  caPath =
    if mtls.pki.caPath != null
    then mtls.pki.caPath
    else "${pkiMount}/cert/ca";

  # niks3's server certificate comes from a private CA, but Nix's `ssl-cert-file`
  # is global to the nix daemon (cache.nixos.org etc.), so it must hold the
  # private CA AND the normal roots. It is a runtime file: the oneshot rebuilds
  # it, atomically, from the CA Vault returns. A missing ssl-cert-file would
  # break EVERY download (not just this cache), so a fallback copy of the system
  # roots is placed at activation (tmpfiles `C`: only if absent) and the file
  # therefore always exists, even before the first successful Vault run.
  bundleFile = "${mtls.certDir}/ca-bundle.pem";
  systemBundle = config.security.pki.caBundle;

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

    # one pkiCert request -> CA, certificate and key together, so a cert can
    # never be paired with the wrong key
    awk -v ca="$work/issued.ca" -v cert="$work/leaf" -v key="$work/key" '
      BEGIN { out = ca }
      $0 == "${certMarker}" { out = cert; next }
      $0 == "${keyMarker}"  { out = key;  next }
      { print > out }
    ' "$in"

    # Never install a mismatched pair.
    if [ "$(openssl x509 -noout -pubkey -in "$work/leaf")" != "$(openssl pkey -pubout -in "$work/key")" ]; then
      echo "niks3-pull-certs: certificate and private key do not match, not installing" >&2
      exit 1
    fi

    # Pick a CA that really validates this leaf (signature AND validity dates):
    # the one read from the mount first, then the one pkiCert returned. The CA
    # becomes part of the nix daemon's trust bundle, so only a CA that vouches
    # for the certificate Vault just issued is ever installed.
    ca=""
    for cand in "${renderedMountCa}" "$work/issued.ca"; do
      [ -s "$cand" ] || continue
      if openssl verify -CAfile "$cand" "$work/leaf" >/dev/null 2>&1; then
        ca="$cand"
        break
      fi
    done
    if [ -z "$ca" ]; then
      echo "niks3-pull-certs: no available CA validates the issued certificate, not installing" >&2
      for cand in "${renderedMountCa}" "$work/issued.ca"; do
        [ -s "$cand" ] || continue
        echo "  tried $(basename "$cand"): $(openssl x509 -noout -subject -enddate -in "$cand" | tr '\n' ' ')" >&2
      done
      exit 1
    fi

    cat "$ca" ${systemBundle} > "$work/bundle"

    install -d -m 0755 ${mtls.certDir}
    install -m 0644 -o root -g root "$work/leaf"   ${mtls.certDir}/client.crt.new
    install -m 0600 -o root -g root "$work/key"    ${mtls.certDir}/client.key.new
    install -m 0644 -o root -g root "$ca"          ${mtls.certDir}/ca.crt.new
    install -m 0644 -o root -g root "$work/bundle" ${bundleFile}.new
    # key first, then certificate: a reader never sees a new cert with an old key
    mv -f ${mtls.certDir}/client.key.new ${mtls.certDir}/client.key
    mv -f ${mtls.certDir}/client.crt.new ${mtls.certDir}/client.crt
    mv -f ${mtls.certDir}/ca.crt.new     ${mtls.certDir}/ca.crt
    mv -f ${bundleFile}.new              ${bundleFile}
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
        mkOpt bool (!isVm && hasVaultAgent)
        ''
          Pull from the internet-facing, client-certificate-gated endpoint
          (`mtls.url`) instead of `url`. vault-agent issues this host a
          read-only certificate (CN niks3-pull-<hostname>) from Vault PKI, a
          oneshot installs it under `mtls.certDir`, and Nix is given the
          substituter URL with `tls-certificate` / `tls-private-key` (Nix >=
          2.34). Works on or off the trusted LAN, where `url` is reachable
          without credentials.

          The CA that signs niks3's server certificate is fetched from Vault
          too (nothing is stored in git) and added to a bundle that becomes the
          (global) `ssl-cert-file`, together with the system roots.

          Defaults to on for physical hosts (hostname not `vm-*`) that run
          vault-agent, and off otherwise. Needs the Vault role in `pki.path`
          and AppRole access to it, so set it to false in flakes without that.
        '';

      url =
        mkOpt str "https://niks3.aicampground.com"
        "Client-certificate-gated niks3 endpoint.";

      certDir =
        mkOpt str "/var/lib/niks3-pull"
        "Where the issued client certificate, key and CA bundle are installed.";

      pki = {
        path =
          mkOpt str "grpc-farm-pki/issue/niks3-pull-client"
          "Vault PKI issue path (mount/issue/role) for the read-only client certificate.";

        caPath =
          mkOpt (nullOr str) null
          ''
            Vault path the PKI mount's CA certificate is read from (field
            "certificate"). Defaults to "<mount>/cert/ca", with <mount> taken
            from `path`. A CA is only ever installed if it validates the issued
            certificate.
          '';

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
      warnings = optional (cfg.publicKey == null) ''
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
          assertion = config.fmf.services.vault-agent.enable;
          message = "fmf.cache.niks3.mtls needs fmf.services.vault-agent.enable = true (the client certificate is issued through Vault).";
        }
      ];

      nix.settings.ssl-cert-file = bundleFile;

      # Always-present fallback for ssl-cert-file (see bundleFile above):
      # `C` copies only if the target does not exist, so a bundle the oneshot
      # already built is never overwritten.
      systemd.tmpfiles.rules = [
        "d ${mtls.certDir} 0755 root root -"
        "C ${bundleFile} 0644 root root - ${systemBundle}"
      ];

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
          files = {
            "pull.pem".text = ''
              {{ with pkiCert "${mtls.pki.path}" "common_name=niks3-pull-${host}" "ttl=${mtls.pki.ttl}" }}{{ .CA }}${certMarker}
              {{ .Cert }}${keyMarker}
              {{ .Key }}{{ end }}
            '';
            # The mount's CA certificate (public). Preferred trust anchor.
            "pull-ca.pem".text = ''
              {{ with secret "${caPath}" }}{{ .Data.certificate }}{{ end }}
            '';
          };
        };
      };
    })
  ]);
}
