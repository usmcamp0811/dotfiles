# README

How to create certs for OpenVPN.

```
vault secrets enable pki

vault write pki/root/generate/internal common_name="campground-vpn" ttl=8760h

vault write pki/config/urls \
  issuing_certificates="https://vault.lan.aicampground.com/v1/pki/ca" \
  crl_distribution_points="https://vault.lan.aicampground.com/v1/pki/crl"

vault write pki/roles/campground-vpn-server-role allowed_domains="aicampground.com" allow_subdomains=true max_ttl=72h


vault write pki/issue/campground-vpn-server-role common_name="vpn.aicampground.com"
```


Here are the templates for each:


### For `server.crt`:

```liquid
{{ with secret "pki/issue/campground-vpn-server-role" "common_name=vpn.aicampground.com" }}
{{ .Data.certificate }}
{{ end }}
```

### For `server.key`:

```liquid
{{ with secret "pki/issue/campground-vpn-server-role" "common_name=vpn.aicampground.com" }}
{{ .Data.private_key }}
{{ end }}
```

### For `ca.crt`:

```liquid
{{ with secret "pki/issue/campground-vpn-server-role" "common_name=vpn.aicampground.com" }}
{{ .Data.issuing_ca }}
{{ end }}
```

Each of these templates uses the `pki/issue/campground-vpn-server-role` path to issue a new certificate for the OpenVPN server with the common name `vpn.aicampground.com`. The templates then extract the relevant parts of the certificate (`certificate`, `private_key`, `issuing_ca`) to populate the respective files (`server.crt`, `server.key`, `ca.crt`).

Place these templates in files (e.g., `server.crt.tpl`, `server.key.tpl`, `ca.crt.tpl`) and reference them in your Vault Agent configuration as shown in the previous example. Vault Agent will use these templates to generate the actual certificate files needed by OpenVPN.
