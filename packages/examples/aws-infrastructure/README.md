# Using Terranix in Your Nix Flake

This document provides instructions on how to use the `terranix` integration functions provided in your Nix Flake. These functions simplify the process of managing Terraform configurations using `terranix` and are designed to integrate with the "Snowfall" approach by organizing Terraform modules in a dedicated directory.

## Functions Overview

### `findDefaultNixFiles`

Recursively scans a directory for `default.nix` files and returns a list of their paths.

#### Parameters

- `path` (string): The directory to scan.

#### Example

```nix
findDefaultNixFiles ./modules
```

### `terranixConfiguration`

Generates a `terranix` configuration, automatically including modules from my flake. This function simplifies the use of `terranix` by acting as a convenient wrapper around its native configuration function.

#### Parameters

- `system` (string): The system identifier (e.g., `x86_64-linux`).
- `extraArgs` (attrset, optional): Additional arguments for the configuration.
- `modules` (list): Paths to extra module files.

#### Example

```nix
terranixConfiguration {
  system = "x86_64-linux";
  modules = [ "./myModule.nix" ];
}
```

### `mkTerranixDerivation`

Creates a derivation that manages Terraform configurations through `terranix`.

#### Parameters

- `pkgs` (package set): Nixpkgs package set.
- `system` (string): The system identifier.
- `extraArgs` (attrset, optional): Additional arguments for the configuration.
- `modules` (list): Paths to module files.

#### Example

```nix
mkTerranixDerivation {
  pkgs = import <nixpkgs> {};
  system = "x86_64-linux";
  modules = [ "./myModule.nix" ];
}
```

The derivation provides the following utilities:

- **`apply`**: Applies the Terraform configuration.
- **`destroy`**: Destroys Terraform-managed resources.
- **`create-state-bucket`**: Creates an S3 bucket for Terraform state storage.

## Directory Structure

Organize your Terraform modules in `./modules/terraform`. Each module should have a `default.nix` file as its entry point.

### Example Directory

```
project-root/
├── flake.nix
├── modules/
│   └── terraform/
│       ├── module1/
│       │   └── default.nix
│       └── module2/
│           └── default.nix
```

## Example Configuration

### Example Module (`example.nix`)

```nix
{ config, pkgs, ... }: {
  config.backend.s3 = {
    bucket = "state-bucket";
    key = "state/example.terraform.tfstate";
    region = "us-east-1";
  };

  config.aws.storage.s3buckets = {
    enable = true;
    region = config.backend.s3.region;
    ip-white-list = [ "0.0.0.0/0" ];
    tags = {
      terranix = "true";
      project = "example-infrastructure";
    };
    buckets = [ "test-bucket" "another-bucket" ];
  };

  config.aws.lambda = {
    enable = true;
    region = config.backend.s3.region;
    lambda = {
      myLambda = {
        functionName = "my-docker-lambda";
        runtime = "provided.al2";
        memorySize = 128;
        timeout = 30;
        role = {
          name = "lambda-exec-role";
          assumeRolePolicy = pkgs.lib.toJSON {
            Version = "2012-10-17";
            Statement = [{
              Effect = "Allow";
              Principal = { Service = "lambda.amazonaws.com"; };
              Action = "sts:AssumeRole";
            }];
          };
        };
        packageType = "Image";
        imageUri = "${config.aws.ecr.repositoryUrl}:latest";
      };
    };
  };
}
```

### Using the Example Configuration

Include the module and generate the derivation in your flake:

```nix
{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.campground;
mkTerranixDerivation {
  inherit pkgs system;
  extraArgs = { };
  modules = [ ./example.nix ];
}
```

### Running the Terraform Configuration

1. View the generated JSON:
   ```bash
   nix run .#aws-infrastructure
   ```
2. Apply the Terraform configuration:
   ```bash
   nix run .#aws-infrastructure.apply
   ```
3. Destroy the Terraform resources:
   ```bash
   nix run .#aws-infrastructure.destroy
   ```

## Notes

- Customize the `modules` list to include all your Terraform modules.
- Use the `create-state-bucket` utility to set up a state bucket for Terraform.

For more information about `terranix`, visit the [official documentation](https://terranix.org/).
