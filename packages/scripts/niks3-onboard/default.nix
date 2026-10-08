{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.fmf) override-meta;

  new-meta = with lib; {
    description = "Issue a client certificate bundle that lets a machine or person push to the niks3 cache (mTLS).";
    license = licenses.asl20;
    maintainers = with maintainers; [mattcamp];
  };

  package = pkgs.writeShellApplication {
    name = "niks3-onboard";
    runtimeInputs = with pkgs; [jq openssl coreutils gnutar gzip];
    text = ''
      usage() {
        cat <<'EOF'
      niks3-onboard - create the mTLS files a machine/person needs for the niks3 cache

      Usage: niks3-onboard <name> [options]

      By default the certificate can PUSH (and read). With --pull it is read-only.

        <name>            who/what this is for, e.g. "butler" or "alice-laptop"
                          (letters, digits and dashes; the cert CN becomes
                          niks3-push-<name> or niks3-pull-<name>)

      Options:
        --pull            read-only certificate (CN niks3-pull-<name>, role
                          niks3-pull-client) for machines that only substitute
        --ttl <dur>       certificate lifetime (default: 4320h = 180 days;
                          the Vault role allows at most 8760h)
        --out <dir>       output directory (default: ./niks3-<push|pull>-<name>)
        --tar             also write <dir>.tar.gz to hand to someone
        --server-url <u>  endpoint (default: https://niks3.aicampground.com)
        --role <role>     Vault PKI role (default: niks3-push-client, or niks3-pull-client with --pull)
        --pki <mount>     Vault PKI mount (default: grpc-farm-pki)
        -h, --help        this help

      Needs a working Vault login (VAULT_ADDR / VAULT_TOKEN, or `vault login`)
      whose token may write <pki>/issue/<role>. Set VAULT_BIN to use a
      different vault binary.

      The private key is written once, to the output directory (mode 600), and
      never printed.
      EOF
      }

      name=""
      ttl="4320h"
      out=""
      tar_it=false
      server_url="https://niks3.aicampground.com"
      role=""
      kind="push"
      pki="grpc-farm-pki"

      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help) usage; exit 0 ;;
          --ttl) ttl="$2"; shift 2 ;;
          --out) out="$2"; shift 2 ;;
          --tar) tar_it=true; shift ;;
          --pull) kind="pull"; shift ;;
          --server-url) server_url="$2"; shift 2 ;;
          --role) role="$2"; shift 2 ;;
          --pki) pki="$2"; shift 2 ;;
          -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
          *)
            if [ -n "$name" ]; then echo "only one <name> allowed" >&2; exit 2; fi
            name="$1"; shift ;;
        esac
      done

      if [ -z "$name" ]; then usage >&2; exit 2; fi
      if ! [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        echo "name must be lowercase letters, digits and dashes: $name" >&2
        exit 2
      fi

      vault_bin="''${VAULT_BIN:-${pkgs.vault-bin}/bin/vault}"
      cn="niks3-$kind-$name"
      if [ -z "$role" ]; then role="niks3-$kind-client"; fi
      out="''${out:-./niks3-$kind-$name}"

      if [ -e "$out" ]; then
        echo "refusing to overwrite existing $out" >&2
        exit 1
      fi

      if ! "$vault_bin" token lookup >/dev/null 2>&1; then
        echo "not logged in to Vault (try: vault login)" >&2
        exit 1
      fi

      umask 077
      mkdir -p "$out"
      raw="$(mktemp "$out/.issue.XXXXXX")"
      trap 'shred -u "$raw" 2>/dev/null || rm -f "$raw"' EXIT

      echo "Issuing $cn from $pki/issue/$role (ttl $ttl)..." >&2
      if ! "$vault_bin" write -format=json "$pki/issue/$role" \
          "common_name=$cn" "ttl=$ttl" >"$raw"; then
        echo "Vault refused (role missing, ttl above the role's max_ttl, or your token lacks update on $pki/issue/$role)" >&2
        rm -rf "$out"
        exit 1
      fi

      jq -er .data.certificate  "$raw" >"$out/client.crt"
      jq -er .data.private_key  "$raw" >"$out/client.key"
      jq -er .data.issuing_ca   "$raw" >"$out/ca.crt"
      serial="$(jq -er .data.serial_number "$raw")"
      chmod 600 "$out/client.key"

      # The niks3 client uses ONE CA setting for every request, including the
      # presigned uploads to the public S3 host (a normal public certificate).
      # So the CA file it gets must contain the private CA AND public roots.
      cat "$out/ca.crt" "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" >"$out/ca-bundle.pem"

      expires="$(openssl x509 -in "$out/client.crt" -noout -enddate | cut -d= -f2)"
      subject="$(openssl x509 -in "$out/client.crt" -noout -subject | sed 's/^subject= *//')"

      if [ "$kind" = push ]; then
        cat >"$out/push.sh" <<EOF
      #!/usr/bin/env bash
      # Push store paths to niks3:  ./push.sh <store paths...>   e.g. ./push.sh ./result
      set -euo pipefail
      here="\$(cd "\$(dirname "\$0")" && pwd)"
      if command -v niks3 >/dev/null 2>&1; then run=(niks3); else run=(nix run github:Mic92/niks3 --); fi
      exec "\''${run[@]}" push \\
        --server-url "$server_url" \\
        --client-cert "\$here/client.crt" --client-key "\$here/client.key" \\
        --ca-cert "\$here/ca-bundle.pem" "\$@"
      EOF
        chmod 700 "$out/push.sh"

        cat >"$out/README.txt" <<EOF
      niks3 PUSH credentials for: $name   (this certificate can also read)
      Subject:  $subject
      Serial:   $serial
      Expires:  $expires
      Endpoint: $server_url

      Files
        client.crt / client.key   your identity (keep client.key private)
        ca-bundle.pem             private CA + public roots (what --ca-cert needs)
        ca.crt                    the private CA alone
        push.sh                   wrapper: ./push.sh ./result

      Quick test
        nix build nixpkgs#hello && ./push.sh ./result

      Plain command (no wrapper)
        niks3 push --server-url $server_url \\
          --client-cert client.crt --client-key client.key \\
          --ca-cert ca-bundle.pem <paths>

      Notes
        - mTLS is the only credential. No niks3 API token or S3 key is needed.
        - Use ca-bundle.pem, not ca.crt, for --ca-cert: uploads go to a public
          S3 host that ca.crt alone does not trust.
        - ca-bundle.pem includes a snapshot of the public CA roots from when it was
          made. Re-run niks3-onboard when you renew.
        - Renew before $expires by running niks3-onboard again.
        - Revoke (admin): vault write $pki/revoke serial_number=$serial
      EOF
      else
        cat >"$out/README.txt" <<EOF
      niks3 PULL (read-only) credentials for: $name
      Subject:  $subject
      Serial:   $serial
      Expires:  $expires
      Endpoint: $server_url

      Install (as root; the nix daemon reads these, so keep the key root-only)
        install -d -m 0755 /etc/niks3
        install -m 0644 client.crt ca-bundle.pem /etc/niks3/
        install -m 0600 client.key /etc/niks3/

      Nix >= 2.34 passes the certificate on the substituter URL:

        # nix.conf  (NixOS: nix.settings.substituters / .ssl-cert-file)
        extra-substituters = $server_url?tls-certificate=/etc/niks3/client.crt&tls-private-key=/etc/niks3/client.key
        ssl-cert-file = /etc/niks3/ca-bundle.pem
        extra-trusted-public-keys = <public half of the niks3 signing key>

      Quick test
        curl --cert client.crt --key client.key --cacert ca-bundle.pem $server_url/nix-cache-info

      Notes
        - ssl-cert-file is GLOBAL for the nix daemon, so it must be the bundle
          (private CA + public roots), not ca.crt alone, or other caches break.
        - Needs Nix >= 2.34 (check: nix --version).
        - This certificate cannot push.
        - Renew before $expires by running niks3-onboard --pull again.
        - Revoke (admin): vault write $pki/revoke serial_number=$serial
      EOF
      fi

      if [ "$tar_it" = true ]; then
        tar -C "$(dirname "$out")" -czf "$out.tar.gz" "$(basename "$out")"
        chmod 600 "$out.tar.gz"
        echo "wrote $out.tar.gz (contains the PRIVATE KEY; send it over a secure channel)" >&2
      fi

      echo >&2
      echo "Done: $out" >&2
      echo "  subject  $subject" >&2
      echo "  serial   $serial" >&2
      echo "  expires  $expires" >&2
      echo "  see $out/README.txt" >&2
    '';
  };
in
  override-meta new-meta package
