{ lib, inputs, ... }:
with lib; rec {

  # Recursively scans a directory and loads all `default.nix` files found.
  #
  # @param path The base directory to scan for `default.nix` files.
  # @return A list of file paths to all `default.nix` files found within the given directory and its subdirectories.
  #
  # Example:
  # ```nix
  # findDefaultNixFiles ./modules
  # ```
  findDefaultNixFiles = path:
    let
      scanDir = dir:
        let
          entries = builtins.readDir dir;
          files = builtins.filter (name:
            let entry = entries.${name};
            in entry == "regular" && builtins.match ".*default\\.nix$" name
            != null) (builtins.attrNames entries);
          filePaths = builtins.map (file: "${dir}/${file}") files;
          subDirs = builtins.filter
            (name: let entry = entries.${name}; in entry == "directory")
            (builtins.attrNames entries);
          subDirPaths = builtins.concatLists
            (builtins.map (subDir: scanDir "${dir}/${subDir}") subDirs);
        in filePaths ++ subDirPaths;
    in scanDir path;

  # Generates a Terranix configuration.
  #
  # @param system The system identifier (e.g., "x86_64-linux").
  # @param extraArgs Optional additional arguments to pass to the configuration.
  # @param modules A list of module paths to include in the configuration.
  #
  # Example:
  # ```nix
  # terranixConfiguration { system = "x86_64-linux"; modules = ["./myModule.nix"]; }
  # ```
  terranixConfiguration = { system, extraArgs ? { }, modules }:
    inputs.terranix.lib.terranixConfiguration {
      inherit system;
      extraArgs = { inherit lib; } // extraArgs;
      modules = findDefaultNixFiles ../../modules/terraform ++ modules;
    };

  # Creates a derivation to manage Terraform configurations via Terranix.
  #
  # @param pkgs The package set to use for dependencies.
  # @param system The system identifier (e.g., "x86_64-linux").
  # @param extraArgs Optional additional arguments to pass to the configuration.
  # @param modules A list of module paths to include in the configuration.
  #
  # The derivation provides utilities for managing Terraform:
  # - `apply`: Applies the Terraform configuration.
  # - `destroy`: Destroys the Terraform-managed resources.
  # - `create-state-bucket`: Creates an S3 bucket for Terraform state storage.
  #
  # Example:
  # ```nix
  # mkTerranixDerivation {
  #   pkgs = import <nixpkgs> {};
  #   system = "x86_64-linux";
  #   modules = ["./myModule.nix"];
  # }
  # ```
  mkTerranixDerivation = { pkgs, system, extraArgs ? { }, modules }:
    let
      terraformConfiguration =
        terranixConfiguration { inherit system extraArgs modules; };

      # Generates the Terraform JSON configuration.
      tf-json = pkgs.writeShellScriptBin "default" ''
        cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
      '';

      # Applies the Terraform configuration.
      apply = pkgs.writeShellScriptBin "apply" ''
        if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
        cp ${terraformConfiguration} config.tf.json \
          && ${pkgs.terraform}/bin/terraform init \
          && ${pkgs.terraform}/bin/terraform apply
      '';

      # Destroys the Terraform-managed resources.
      destroy = pkgs.writeShellScriptBin "destroy" ''
        if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
        cp ${terraformConfiguration} config.tf.json \
          && ${pkgs.terraform}/bin/terraform init \
          && ${pkgs.terraform}/bin/terraform destroy
      '';

      # Creates an S3 bucket for Terraform state storage.
      create-state-bucket = pkgs.writeShellScriptBin "create-state-bucket" ''
        set -euo pipefail

        BUCKET_NAME=''${1:-"state-bucket"}
        AWS_REGION=''${2:-"us-east-1"}

        echo "Creating S3 bucket '$BUCKET_NAME' in region '$AWS_REGION'..."

        aws s3api create-bucket \
          --bucket "$BUCKET_NAME" \
          --region "$AWS_REGION" \
          $(if [ "$AWS_REGION" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=$AWS_REGION"; fi)

        echo "Enabling versioning on the bucket $BUCKET_NAME..."
        aws s3api put-bucket-versioning \
          --bucket "$BUCKET_NAME" \
          --versioning-configuration Status=Enabled

        echo "Setting default encryption on the bucket $BUCKET_NAME..."
        aws s3api put-bucket-encryption \
          --bucket "$BUCKET_NAME" \
          --server-side-encryption-configuration '{
            "Rules": [{
              "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
              }
            }]
          }'

        echo "Bucket $BUCKET_NAME setup is complete."
      '';
    in tf-json // { inherit apply destroy create-state-bucket; };
}
