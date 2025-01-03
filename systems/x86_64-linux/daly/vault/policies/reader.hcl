
path "secret/ata" {
  capabilities = ["list"]
}
path "secret/data/ata/*" {
  capabilities = ["list"]
}

path "secret/ata/data/*" {
  capabilities = ["list"]
}
