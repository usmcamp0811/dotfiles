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
