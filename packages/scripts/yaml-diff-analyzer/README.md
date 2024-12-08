# YAML Diff Analyzer

A script to compare two YAML files, identify differences, and optionally map the differences to related
environment variables. This tool was created to simplify debugging large YAML files, such as Helm values
files, by making it easier to pinpoint and contextualize differences.

## Purpose

While deploying configurations to Kubernetes, comparing the currently deployed Helm values YAML with
a new set of values can be a tedious process—especially when dealing with large YAML files spanning hundreds
of lines. This script helps:

1. Quickly identify differences between two YAML files.
2. Optionally map the differences to relevant entries in an environment variables YAML for added context.
3. Output the results in a clear and human-readable format.

## Features

- **Deep YAML comparison**: Detects additions, deletions, and modifications between two YAML files.
- **Optional environment lookup**: Map differences to related values in a third YAML file for additional context.
- **Readable output**: Outputs paths and values in a format that is easy to review.
- **Command-line arguments**: Specify file paths for easy use in different contexts.

## Usage

### Command-line Arguments

```bash
nix run gitlab:usmcamp0811/dotfiles#yaml-diff-analyzer <file1> <file2> [--env-file <env_file>]
```

- `<file1>`: Path to the first YAML file (e.g., the deployed Helm values).
- `<file2>`: Path to the second YAML file (e.g., the new Helm values to deploy).
- `--env-file <env_file>` (optional): Path to a third YAML that might have more context, such as ENV
  variables that get interpolated at deploy time.

### Examples

#### Basic YAML Comparison

Compare two YAML files and list their differences:

```bash
nix run gitlab:usmcamp0811/dotfiles#yaml-diff-analyzer -- deployed.yaml new.yaml
```

#### YAML Comparison with Environment Variable Mapping

Add context to the differences by including a third YAML file for lookups:

```bash
nix run gitlab:usmcamp0811/dotfiles#yaml-diff-analyzer -- deployed.yaml new.yaml --env-file env-vars.yaml
```

The script will include the corresponding value from `env-vars.yaml` (if available) in the output.

## Output Format

The output is a list of differences in YAML format, with each entry showing:

- `path`: The path to the changed value in the YAML file.
- `file1`: The value from the first YAML file.
- `file2`: The value from the second YAML file.
- `env_var_value` (if provided): The related value from the environment variables YAML.

### Example Output

```yaml
- path: app.config.replicas
  file1: 3
  file2: 5
  env_var_value: replica_count

- path: app.secrets.api_key
  file1: secret123
  file2: secret456
  env_var_value: 'Not Found'
```

If the `--env-file` flag is omitted, the `env_var_value` field is not included.

## Why Use This?

This tool was born out of a need to debug Helm deployments quickly. Searching through an 800-line YAML file for mismatches between deployed and intended configurations is a daunting task. By automating the comparison and providing contextual insights, this script saves time and reduces errors.

Whether you're working with Kubernetes, CI/CD pipelines, or complex configuration files, **YAML Diff Analyzer** streamlines the process of identifying and resolving discrepancies.
