path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/campground/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/campground/data/*" {
  capabilities = ["read", "list"]
}

# TODO: Move all vpn policies to a seperate policy
# Allow reading from the PKI secrets engine to issue server certificates
path "campground-vpn/issue/campground-vpn-server-role" {
  capabilities = ["create", "read", "update"]
}

# Allow reading from the PKI secrets engine to issue client certificates
path "campground-vpn/issue/campground-vpn-client-role" {
  capabilities = ["create", "read", "update"]
}

# Allow reading the CA certificate
path "campground-vpn/ca" {
  capabilities = ["read"]
}

# Allow reading the CRL configuration
path "campground-vpn/crl" {
  capabilities = ["read"]
}

path "campground-vpn/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/login" {
  capabilities = ["create", "read"]
}

