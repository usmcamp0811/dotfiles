{ lib, ... }: rec {
  ## Append text to the contents of a file
  ##
  ## ```nix
  ## fileWithText ./some.txt "appended text"
  ## ```
  ##
  #@ Path -> String -> String
  fileWithText = file: text: ''
    ${builtins.readFile file}
    ${text}'';

  ## Prepend text to the contents of a file
  ##
  ## ```nix
  ## fileWithText' ./some.txt "prepended text"
  ## ```
  ##
  #@ Path -> String -> String
  fileWithText' = file: text: ''
    ${text}
    ${builtins.readFile file}'';

  #
  # Creates a shell script that injects secrets into a YAML file.
  #
  # This function generates a script that can be used to inject secrets
  # into a YAML file by substituting environment variables into the
  # input YAML. The script leverages `vault` for secret management,
  # `envsubst` to replace variables, and `yq` to manipulate YAML.
  #
  # Parameters:
  # - `name`: (string) The name of the script binary to be created.
  # - `env`: (attrs) Environment attributes, unused in this function but kept for future customization.
  # - `secrets`: (string) Path to a script that sets environment variables, typically using values fetched from Vault.
  #   The secrets script should have lines similar to:
  #   ```
  #   export AWS_ACCESS_KEY_ID=$(vault kv get -field=AWS_ACCESS_KEY_ID secret/campground/mlflow)
  #   ```
  #   This script sets the necessary environment variables used in the YAML interpolation.
  # - `inputYaml`: (string) Path to the YAML file in which secrets should be injected.
  #
  # Example usage:
  # ```
  # mkSecretYaml {
  #   name = "inject-secrets";
  #   env = {};  # Attributes for additional environment settings.
  #   secrets = ./secrets.sh;  # Path to the script containing environment variables.
  #   inputYaml = ./values.yaml;  # Path to the YAML file to be processed.
  # }
  # ```
  #
  # The generated script does the following:
  # - Loads secrets from the provided script.
  # - Reads and substitutes environment variables into the input YAML.
  # - Formats the resulting YAML using `bat` with syntax highlighting.
  #
  # Note:
  # This function is particularly useful for injecting secrets into
  # Helm `values.yaml` files, but it can be used for any YAML that
  # requires secrets or dynamic values.
  mkSecretYaml = { pkgs, name, env, secrets, inputYaml }:
    pkgs.writeShellScriptBin name ''
      # fail fast!
      set -e
      export PATH=$PATH:${pkgs.vault-bin}/bin
      if [ -z "$VAULT_ADDR" ]; then
          echo "Error: VAULT_ADDR is not set. Please set it and try again."
          exit 1
      fi

      source "${secrets}"
      ${pkgs.bat}/bin/bat -p ${inputYaml} | ${pkgs.envsubst}/bin/envsubst | ${pkgs.yq}/bin/yq -y | ${pkgs.bat}/bin/bat --language yaml
    '';
}
