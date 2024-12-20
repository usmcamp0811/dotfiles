{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.vault;

  package = if cfg.ui then pkgs.vault-bin else pkgs.vault;

  has-policies = (builtins.length (builtins.attrNames cfg.policies)) != 0;

  format-policy = name: file:
    pkgs.runCommandNoCC "formatted-vault-policy"
      {
        inherit file;
        buildInputs = [ package ];
      } ''
      name="$(basename "$file")"

      cp "$file" "./$name"

      # Ensure that vault can overwrite the file.
      chmod +w "./$name"

      # Create this variable here to avoid swallowing vault's exit code.
      vault_output=

      set +e
      vault_output=$(vault policy fmt "./$name" 2>&1)
      vault_status=$?
      set -e

      if [ "$vault_status" != 0 ]; then
        echo 'Error formatting policy "${name}"'
        echo "This is normally caused by a syntax error in the policy file."
        echo "$file"
        echo ""
        echo "Vault Output:"
        echo "$vault_output"
        exit 1
      fi

      mv "./$name" $out
    '';

  policies = mapAttrs
    (name: value:
      if builtins.isPath value then
        format-policy name value
      else
        format-policy name (pkgs.writeText "${name}.hcl" value))
    cfg.policies;

  unseal-script = pkgs.writeShellScriptBin "clevis-unseal-vault" ''
    # Path to the encrypted file containing the unseal key
    encrypted_file="${cfg.tang-unseal-key}"

    # Vault address (e.g., local or cluster address)
    vault_addr="http://127.0.0.1:8200"

    # Max retries and delay for checking readiness
    max_retries=30
    delay=2

    # Check if Vault is ready by querying the UI endpoint
    is_vault_ready() {
        for i in $(seq 1 $max_retries); do
            if ${pkgs.curl}/bin/curl -s "$vault_addr/ui/" | grep -q .; then
                return 0
            fi
            echo "Waiting for Vault to be ready... ($i/$max_retries)"
            sleep $delay
        done
        return 1
    }

    # Check if Vault is sealed
    is_sealed() {
        ${package}/bin/vault status -address="$vault_addr" 2>/dev/null | grep -q "Sealed.*true"
        return $?
    }

    # Unseal Vault using the key from the encrypted file
    unseal_vault() {
        echo "Attempting to unseal Vault..."
        unseal_key=$(${pkgs.clevis}/bin/clevis decrypt < "$encrypted_file")
        if [ $? -ne 0 ]; then
            echo "Error: Failed to decrypt the unseal key."
            exit 1
        fi

        ${package}/bin/vault operator unseal -address="$vault_addr" "$unseal_key"
        if [ $? -eq 0 ]; then
            echo "Vault successfully unsealed."
        else
            echo "Error: Failed to unseal Vault."
            exit 1
        fi
    }

    # Main logic
    echo "Checking if Vault is ready..."
    if is_vault_ready; then
        echo "Vault is ready."
        if is_sealed; then
            echo "Vault is sealed. Proceeding to unseal."
            unseal_vault
        else
            echo "Vault is already unsealed. No action required."
        fi
    else
        echo "Vault did not become ready within the allotted time. Exiting."
        exit 0
    fi
  '';

  write-policies-commands = mapAttrsToList
    (name: policy: ''
      echo Writing policy '${name}': '${policy}'
      vault policy write '${name}' '${policy}'
    '')
    policies;
  write-policies = concatStringsSep "\n" write-policies-commands;

  known-policies = mapAttrsToList (name: _value: name) policies;

  remove-unknown-policies = ''
    current_policies=$(vault policy list -format=json | jq -r '.[]')
    known_policies=(${
      concatStringsSep " "
      (builtins.map (policy: ''"${policy}"'') known-policies)
    })

    while read current_policy; do
      is_known=false

      for known_policy in "''${known_policies[@]}"; do
        if [ "$known_policy" = "$current_policy" ]; then
          is_known=true
          break
        fi
      done

      if [ "$is_known" = "false" ] && [ "$current_policy" != "default" ] && [ "$current_policy" != "root" ]; then
        echo "Removing policy: $current_policy"
        vault policy delete "$current_policy"
      else
        echo "Keeping policy: $current_policy"
      fi
    done <<< "$current_policies"
  '';
in
{
  options.campground.services.vault = {
    enable = mkEnableOption "Vault";
    ui = mkBoolOpt true "Whether the UI should be enabled.";
    auto-unseal =
      mkBoolOpt false "Whether or not to auto unseal with Clevis & Tang";
    tang-unseal-key = mkOpt types.str "/var/lib/vault/unsealkey.enc"
      "Location of a Tang encrypted unseal key";
    storage = {
      backend = mkOpt types.str "file" "The storage backend for Vault.";
      path = mkOpt types.str "/var/lib/vault/data" "Path";
      config = mkOpt (types.nullOr types.str) null "Config";
    };
    address = mkOpt types.str "0.0.0.0:8200" "Where to access vault UI at";
    settings = mkOpt types.str "" "Configuration for Vault's config file.";
    mutable-policies = mkBoolOpt false
      "Whether policies not specified in Nix should be removed.";
    policies = mkOpt (types.attrsOf (types.either types.str types.path)) { }
      "Policies to install when Vault runs.";
    policy-agent = {
      user = mkOpt types.str "root" "The user to run the Vault Agent as.";
      group = mkOpt types.str "root" "The group to run the Vault Agent as.";
      auth = {
        roleIdFilePath = mkOpt types.str "/var/lib/vault/vault/role-id"
          "The file to read the role-id from.";
        secretIdFilePath = mkOpt types.str "/var/lib/vault/vault/secret-id"
          "The file to read the secret-id from.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.vault = {
      enable = true;
      address = cfg.address;
      inherit package;
      storageBackend = cfg.storage.backend;
      storagePath = cfg.storage.path;
      storageConfig = cfg.storage.config;
      extraConfig = ''
        ui = ${if cfg.ui then "true" else "false"}

        ${cfg.settings}
      '';
    };

    systemd.services.vault.postStart =
      mkIf (cfg.auto-unseal && cfg.tang-unseal-key != null)
        "${unseal-script}/bin/clevis-unseal-vault";

    systemd.services.vault-policies =
      mkIf (has-policies || !cfg.mutable-policies) {
        wantedBy = [ "vault.service" ];
        after = [ "vault.service" ];

        serviceConfig = {
          Type = "oneshot";
          User = cfg.policy-agent.user;
          Group = cfg.policy-agent.group;
          Restart = "on-failure";
          RestartSec = 30;
          RemainAfterExit = "yes";
        };

        restartTriggers =
          mapAttrsToList (name: value: "${name}=${value}") policies;

        path = [ package pkgs.curl pkgs.jq ];

        environment = {
          VAULT_ADDR = "http://${config.services.vault.address}";
        };

        script = ''
          if ! [ -f '${cfg.policy-agent.auth.roleIdFilePath}' ]; then
            echo 'role-id file not found: ${cfg.policy-agent.auth.roleIdFilePath}'
            exit 0
          fi

          if ! [ -f '${cfg.policy-agent.auth.secretIdFilePath}' ]; then
            echo 'secret-id file not found: ${cfg.policy-agent.auth.secretIdFilePath}'
            exit 0
          fi

          role_id="$(cat '${cfg.policy-agent.auth.roleIdFilePath}')"
          secret_id="$(cat '${cfg.policy-agent.auth.secretIdFilePath}')"

          seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq ".sealed")

          echo "Seal Status: $seal_status"

          if [ seal_status = "true" ]; then
            echo "Vault is currently sealed, cannot install policies."
            exit 1
          fi

          echo "Getting token..."

          token=$(vault write -field=token auth/approle/login \
            role_id="$role_id" \
            secret_id="$secret_id" \
          )

          echo "Logging in..."

          export VAULT_TOKEN="$(vault login -method=token -token-only token="$token")"

          echo "Writing policies..."

          ${write-policies}

          ${optionalString (!cfg.mutable-policies) remove-unknown-policies}
          exit 0
        '';
      };
  };
}
