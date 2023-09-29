# README: Setting Up an OpenVPN Server with Vault-Generated Certificates on NixOS

This README provides a comprehensive guide on how to set up an OpenVPN server on NixOS, with certificates generated and managed by HashiCorp Vault.

## Prerequisites

- A running Vault instance
- Basic understanding of Nix and NixOS
- Vault CLI installed or Vault UI accessible

## Step 1: Enable PKI Secrets Engine in Vault

Enable the PKI secrets engine and configure it to issue certificates.

```bash
vault secrets enable pki

vault write pki/root/generate/internal common_name="campground-vpn" ttl=8760h

vault write pki/config/urls \
  issuing_certificates="https://vault.lan.aicampground.com/v1/pki/ca" \
  crl_distribution_points="https://vault.lan.aicampground.com/v1/pki/crl"
```

## Step 2: Create a Role in Vault

Create a role that will define the properties of the certificates to be issued.

```bash
vault write pki/roles/campground-vpn-server-role allowed_domains="aicampground.com" allow_subdomains=true max_ttl=72h
```

## Step 3: Issue a Certificate

Issue a certificate based on the role created. The `common_name` is crucial as it identifies the certificate.

```bash
vault write pki/issue/campground-vpn-server-role common_name="vpn.aicampground.com"
```

## Step 4: Vault Agent Templates

Create Vault Agent templates to fetch the necessary certificate files dynamically.

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

Place these templates in files (e.g., `server.crt.tpl`, `server.key.tpl`, `ca.crt.tpl`) and reference them in your Vault Agent configuration.

## Step 5: NixOS Configuration

In your NixOS configuration, set up the OpenVPN service and a systemd service to fetch the certificates from Vault. Make sure to specify the user under which OpenVPN will run. If you're using a custom user like `ovpn`, you'll need to create that user and group manually in your NixOS configuration.

```nix
users.users.ovpn = {
  isSystemUser = true;
  group = "ovpn";
  description = "OpenVPN service user";
};

users.groups.ovpn = {};
```

## Step 6: Diffie-Hellman Parameters

Generate Diffie-Hellman parameters for added security. This can be CPU-intensive and might slow down the service startup.

```bash
openssl dhparam -out dh.pem 2048
```

## Additional Notes

- **Service Dependencies**: Ensure that Vault Agent is running and authenticated before your OpenVPN service starts.
- **Permissions**: Set permissions to `0600` for the certificates and keys.
- **Error Handling**: Log errors for debugging.
- **Firewall Rules**: Ensure your firewall allows traffic on the OpenVPN port (default 1194/UDP).

By following these steps, you should have a fully functional OpenVPN server with certificates managed by Vault.


### Generating Client Certificates

You can create a new role in Vault specifically for OpenVPN clients and then issue certificates based on that role. Here's how you can set it up:

1. **Create a Role for OpenVPN Clients**

    ```bash
    vault write pki/roles/campground-vpn-client-role \
      allowed_domains="client.aicampground.com" \
      allow_subdomains=true max_ttl=72h
    ```

2. **Generate a Client Certificate**

    ```bash
    vault write pki/issue/campground-vpn-client-role common_name="client1.client.aicampground.com"
    ```

    This will output the client certificate, private key, and the CA certificate. You can put these into your client's OpenVPN configuration.

### Revoking Certificates

Vault's PKI secrets engine allows you to revoke certificates. To revoke a certificate, you'll need its serial number. You can find this in the certificate details.

1. **Revoke a Certificate**

    ```bash
    vault write pki/revoke serial_number="XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
    ```

    This will mark the certificate as revoked and update the CRL (Certificate Revocation List).

2. **Update OpenVPN to Use CRL**

    You'll need to configure OpenVPN to use this CRL. Add the following line to your OpenVPN server configuration:

    ```bash
    crl-verify /path/to/crl.pem
    ```

    You can download the updated CRL from Vault and place it in the specified path.

By following these steps, you can generate client certificates and also have the ability to revoke them when needed.
