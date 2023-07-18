# How to use Hashicorp Vault to Manage Secrets

## Create Policy

```hcl
path "secret/campground" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

```bash
vault policy write campground-policy campground_secrets.hcl
```

## Create an Authentication Method

Need to enable `approle` authentication.

```bash
vault auth enable approle
vault write auth/approle/role/campground-role policies=campground-policy
```


## Get the role ID and the Secret ID

These commands will output the role ID and secret ID, respectively. 
You'll need to provide these to your application, for example by writing 
them to the /role_id and /secret_id files as in the previous example.

```bash
vault read auth/approle/role/campground-role/role-id
vault write -f auth/approle/role/campground-role/secret-id
```

## Write the Secrets

```bash
vault kv put secret/campground value=my-super-secret-value
```
