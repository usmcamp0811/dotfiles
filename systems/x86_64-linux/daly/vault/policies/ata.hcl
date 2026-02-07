
path "secret/ata" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/ata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/ata/data/*" {
  capabilities = ["read", "list"]
}
