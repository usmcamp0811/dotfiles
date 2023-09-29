path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/campground/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/campground/data/*" {
  capabilities = ["read", "list"]
}

# Allow reading from the PKI secrets engine to issue certificates
path "pki/issue/campground-vpn-server-role" {
  capabilities = ["create", "read", "update"]
}

# Allow reading the CA certificate
path "pki/ca" {
  capabilities = ["read"]
}

# Allow reading the CRL configuration
path "pki/crl" {
  capabilities = ["read"]
}

path "pki/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

