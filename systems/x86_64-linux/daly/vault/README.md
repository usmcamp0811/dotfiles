# README


This will not build fully the first go because vault isn't setup.

`update-sys`

then go create the Vault / unseal

Next to make this vault plicy-agent work you need to go create an approle for the vault policy agent thing. Then go give that approle the vault-policies.hcl policy. 
Store the `secret-id` and `vault-id` files at `/var/lib/vault/*` unless you wanna go specify it in your config. After this everything will
build correctly. 

##TODO: Figure out where on disk the data is at.
