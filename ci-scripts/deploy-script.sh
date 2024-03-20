#!/usr/bin/bash

# Manually setup the environment
export PATH=$(nix shell nixpkgs#expect nixpkgs#vault --command echo $PATH)

# Variables
hostname="$1"
kv_path="secret/campground/local-users-passwords"

# Login to Vault
vault login -method=approle role_id="./role_id" secret_id="./secret_id" > /dev/null

# Get password from Vault
password=$(vault kv get -field="$DEPLOY_USER" "$kv_path")

# Execute the deploy command with expect
/usr/bin/env -S nix shell nixpkgs#expect --command expect <<EOF
set timeout 600

spawn deploy --interactive-sudo true --hostname $hostname .#$hostname
expect "(sudo for $hostname) Password:"
send "$password\r"
interact
EOF

