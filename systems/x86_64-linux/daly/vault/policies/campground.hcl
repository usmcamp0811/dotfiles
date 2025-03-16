path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/campground/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/campground/data/cloudflare/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/campground/data/*" {
  capabilities = ["read", "list"]
}

path "secret/campground/k0s" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "secret/campground/data/k0s" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

# TODO: Move all vpn policies to a seperate policy
# Allow reading from the PKI secrets engine to issue server certificates
path "campground-pki/issue/vpn-server-role" {
  capabilities = ["create", "read", "update"]
}

# Allow reading from the PKI secrets engine to issue client certificates
path "campground-pki/issue/vpn-client-role" {
  capabilities = ["create", "read", "update"]
}

path "campground-pki/issue/vpn-server-role" {
  capabilities = ["create", "read", "update"]
}

path "campground-pki/issue/*" {
  capabilities = ["create", "read", "update"]
}

# Allow reading the CA certificate
path "campground-pki/ca" {
  capabilities = ["read"]
}

# Allow reading the CRL configuration
path "campground-pki/crl" {
  capabilities = ["read"]
}

path "campground-pki/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/login" {
  capabilities = ["create", "read"]
}

path "sys/storage/raft/snapshot" {
    capabilities = ["read"]
}

# Allow listing all secrets under the `secret` mount
path "secret/*" {
  capabilities = ["list"]
}

# Allow listing and reading all secrets under the `secret/data` path
path "secret/data/*" {
  capabilities = ["read", "list"]
}

# Specific policy for `campground` secrets (already present but kept for clarity)
path "secret/data/campground/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

