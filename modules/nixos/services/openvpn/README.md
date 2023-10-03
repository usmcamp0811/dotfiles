# README: Setting Up an OpenVPN Server with Vault-Generated Certificates on NixOS

This README provides a comprehensive guide on how to set up an OpenVPN server on NixOS, with certificates generated and managed by HashiCorp Vault.

## Prerequisites

- A running Vault instance
- Basic understanding of Nix and NixOS
- Vault CLI installed or Vault UI accessible

## Step 1: Enable PKI Secrets Engine in Vault

Enable the PKI secrets engine and configure it to issue certificates.

We set `ttl=8760h` meaning the cert if valid for 1 year. We don't set `max_ttl` so that we can just renew the certificate and not change things.

```bash
vault secrets enable -path=campground-pki pki


vault write campground-pki/root/generate/internal common_name="campground-pki" ttl=8760h

vault write campground-pki/config/urls \
  issuing_certificates="https://vault.lan.aicampground.com/v1/pki/ca" \
  crl_distribution_points="https://vault.lan.aicampground.com/v1/pki/crl"
```

## Step 2: Create a Role in Vault

Create a role that will define the properties of the certificates to be issued.

```bash
vault write campground-pki/roles/vpn-server-role \
  allowed_domains="aicampground.com" \
  allow_subdomains=true \
  max_ttl=336h
```

This role is required for being able to generate client certs. 

```bash
vault write campground-pki/roles/vpn-client-role \
    allowed_domains="client.aicampground.com" \
    allow_subdomains=true max_ttl=336h
```

## Step 2.1: Create TLS Key

This helps avoid 

The `tls-auth` key in OpenVPN serves as an additional layer of security on top of the TLS control channel to harden it against DoS attacks, port scanning, and buffer overflow vulnerabilities. It's a shared secret key that is used by both the server and all its clients.

The key essentially signs each packet's HMAC hash with a signature that can only be verified by the opposite side knowing the same `tls-auth` key. This provides an early stage filter for unauthorized clients and potentially malicious third parties.

The `tls-auth` directive adds this HMAC signature to the TLS control channel to protect against:

- DoS attacks by an unauthenticated client
- Port flooding
- Buffer overflow vulnerabilities

It's not mandatory but is an extra layer of security.

generate it like this:

```
openvpn --genkey secret ta.key 
```

Then put in a vault KV store somewhere like `secret/campgrouns/vpn/` with the key `tls` 

This can't be generated on the fly because the clients need it also

## Step 3: Issue a Certificate

Issue a certificate based on the role created. The `common_name` is crucial as it identifies the certificate.

This needs to be take and put into the vpn server because this is the server cert

```bash
vault write campground-pki/issue/server-role common_name="vpn.aicampground.com"
```

## Step 4: Vault Agent Templates

Create Vault Agent templates to fetch the necessary certificate files dynamically.

### For `server.crt`:

```liquid
{{ with secret "campground-pki/issue/campground-pki-server-role" "common_name=vpn.aicampground.com" }}
{{ .Data.certificate }}
{{ end }}
```

### For `server.key`:

```liquid
{{ with secret "campground-pki/issue/campground-pki-server-role" "common_name=vpn.aicampground.com" }}
{{ .Data.private_key }}
{{ end }}
```

### For `ca.crt`:

```liquid
{{ with secret "campground-pki/issue/campground-pki-server-role" "common_name=vpn.aicampground.com" }}
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
    vault write pki/roles/campground-pki-client-role \
      allowed_domains="client.aicampground.com" \
      allow_subdomains=true max_ttl=h
    ```

2. **Generate a Client Certificate**

    ```bash
    vault write pki/issue/campground-pki-client-role common_name="client1.client.aicampground.com"
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


### Vault PKI Setup

Enable the PKI secrets engine and configure it.

```bash
vault secrets enable pki
vault write pki/root/generate/internal common_name="campground-pki" ttl=8760h
vault write pki/config/urls \
  issuing_certificates="https://vault.lan.aicampground.com/v1/pki/ca" \
  crl_distribution_points="https://vault.lan.aicampground.com/v1/pki/crl"
```

### Vault Role Creation

Create a role to define certificate properties. `max_ttl` says that certs created with this role will be valid for no longer than 2 weeks (336h)

The server role and client role are used for different purposes:

The server role is used to generate certificates for the VPN server itself.
The client role is used to generate certificates for the VPN clients.
If the server certificate expires, it won't affect the client certificates. They have their own separate lifetimes defined by their respective max_ttl settings. So, you're correct: you use the server role to create server certs and the client role to create client certs, and they operate independently of each other.

```bash
vault write pki/roles/vpn-server-role \
  allowed_domains="aicampground.com" \
  allow_subdomains=true \
  max_ttl=336h
```

This role is required for being able to generate client certs. 
```bash
vault write pki/roles/vpn-client-role \
    allowed_domains="client.aicampground.com" \
    allow_subdomains=true max_ttl=336h
```

### NixOS Configuration

In your NixOS configuration, enable the OpenVPN service and specify the clients.

```nix
{
  campground.services.openvpn = {
    enable = true;
    clients = [
      "butler"
      "oconus"
      "pixel"
    ];
  };
}
```

### Client Certificate Generation

Generate client certificates using the script `generate-client-ovpn`.

```bash
generate-client-ovpn client-name
```

This will generate a client certificate and record its serial number and common name in a CSV file (`vpn-cert-csv` in your NixOS configuration).

#### CSV File Format

- `Serial Number`: Certificate's serial number.
- `Common Name`: Certificate's common name.

Example:

```csv
Serial Number,Common Name
01:23:45:67:89:AB:CD:EF,client1.client.aicampground.com
```

### Revoking Certificates

To revoke a certificate:

1. Find its serial number in the CSV file.
2. Run:

```bash
vault write pki/revoke serial_number="XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
```

This will revoke the certificate and update the CRL.

---

By following this guide, you'll have a functional OpenVPN server with Vault-managed certificates, and the ability to track and revoke them as needed.
