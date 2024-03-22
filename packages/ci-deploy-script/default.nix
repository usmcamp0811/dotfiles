{ inputs, lib, writeShellApplication, pkgs, ... }:

writeShellApplication {
  name = "get-lan-pub-systems";
  meta = { mainProgram = "get-lan-pub-systems"; };
  text = ''
    # Variables
    hostname="$1"
    kv_path="secret/campground/gitlab-runner"

    # Login to Vault
    vault login -method=approle role_id="./role_id" secret_id="./secret_id" > /dev/null

    # Get password from Vault
    sshkey=$(vault kv get -field="sshkey" "secret/campground/gitlab-runner")

    # Execute the deploy command with expect
    /usr/bin/env -S nix shell nixpkgs#expect --command expect <<EOF
    set timeout 600

    spawn deploy --interactive-sudo true --hostname $hostname .#$hostname
    expect "(sudo for $hostname) Password:"
    send "$password\r"
    interact
    EOF
  '';
}
