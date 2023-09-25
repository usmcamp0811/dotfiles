path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/campground/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/campground/data/*" {
  capabilities = ["read", "list"]
}

