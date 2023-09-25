# README


This will not build fully the first go because vault isn't setup.

`update-sys`

then go create the Vault / unseal

Next to make this vault plicy-agent work you need to go create an approle for the vault policy agent thing. Then go give that approle the vault-policies.hcl policy. 
Store the `secret-id` and `vault-id` files at `/var/lib/vault/*` unless you wanna go specify it in your config. After this everything will
build correctly. 


Something like this needs to be done:

```sh
sudo chown -R vault:vault /persist/vault
# done in the policies dir
vault policy write vault-policy vault-policies.hcl

# Create the AppRole named 'vault'
vault auth enable approle
vault write auth/approle/role/vault token_policies="vault-policy"

# Fetch RoleID and SecretID and store them in files
vault read -field=role_id auth/approle/role/vault/role-id | sudo tee /var/lib/vault/role-id
vault write -f -field=secret_id auth/approle/role/vault/secret-id | sudo tee /var/lib/vault/secret-id

sudo chown vault:vault /var/lib/vault/*-id
sudo chmod 0400 /var/lib/vault/*-id

```
