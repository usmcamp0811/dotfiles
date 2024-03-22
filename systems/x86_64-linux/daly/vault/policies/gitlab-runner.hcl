path "secret/campground/gitlab-runner/*" {
  capabilities = ["create", "read", "list"]
}

path "secret/data/campground/gitlab-runner/*" {
  capabilities = ["create", "read", "list"]
}

path "secret/campground/data/gitlab-runner" {
  capabilities = ["create", "read", "list"]
}

path "auth/approle/login" {
  capabilities = ["create", "read"]
}
