# Make an AWS Lambda Image with Nix

Starting a new role and need to create AWS resources, including Lambda functions? Nix provides a powerful
and deterministic way to package your Lambda functions into Docker images. This example demonstrates
how to use Nix to define and package a Python-based AWS Lambda function, inspired by [this codebase](https://github.com/wagdav/nix-aws-lambda-example/tree/main).

## Overview

This example includes:

- A reusable function, `mkAWSLambdaPythonImage`, to create AWS Lambda-compatible Docker images.
- An example Lambda function (`wttr-lambda`) showcasing how to use the `mkAWSLambdaPythonImage` function.
- Preconfigured scripts for local testing (`aws-lambda-rie`) and hot-reload development (`devserver`).

## Example Lambda Function Definition

Here is how the `wttr-lambda` example Lambda function is defined:

```nix
{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.campground;
mkAWSLambdaPythonImage {
  inherit pkgs system;
  name = "wttr-lambda";
  handler = "simple_lambda_function.handler";
  src = ./.;
  pythonEnv =
    pkgs.python3.withPackages (ps: [ ps.awslambdaric ps.requests ps.jsons ]);
}
```

### Key Attributes

- **`name`**: The name of the Docker image.
- **`handler`**: The Python function that AWS Lambda should invoke.
- **`src`**: The source directory containing the Python code.
- **`pythonEnv`**: A Nix-defined Python environment with required packages.

## Reusable Function: `mkAWSLambdaPythonImage`

The `mkAWSLambdaPythonImage` function creates an AWS Lambda-compatible Docker image. Below are its key parameters:

- **`name`**: Name of the Docker image (default: `aws-lambda-with-nix`).
- **`handler`**: The Lambda handler function (e.g., `file.function_name`).
- **`src`**: Source path of the Python code.
- **`pythonEnv`**: A Python environment with required packages (default includes `awslambdaric`).

The function outputs:

1. A Docker image with the application code and runtime.
2. Preconfigured scripts for local testing and development.

## Local Testing and Development

Two scripts are included for streamlined development and testing:

1. **`aws-lambda-rie`**:
   A script to emulate the AWS Lambda Runtime Interface locally.

   ```bash
   ./aws-lambda-rie -d /path/to/code -p 9001 -h 0.0.0.0 lambda_function.handler
   ```

2. **`devserver`**:
   A hot-reload development server that restarts the emulator on code changes.

   ```bash
   ./devserver -d /path/to/code -p 9001 -h 0.0.0.0 lambda_function.handler
   ```

## How to Use

1. **Build the Docker image**:

   ```bash
   nix build gitlab:usmcamp0811/dotfiles#aws-lambda-image
   ```

> TODO: Show how to use Terranix 2. **Run the Lambda locally**: 3. **Deploy to AWS**:

Use the built Docker image with AWS Lambda by uploading it to Amazon ECR and configuring it as the Lambda runtime.

## Customization

The `mkAWSLambdaPythonImage` function can be easily customized for different projects by:

- Adjusting the `pythonEnv` to include additional dependencies.
- Modifying the `src` path to point to your codebase.
- Changing the `handler` to reference your Lambda handler function.

## Conclusion

This example demonstrates the power of Nix for creating and managing AWS Lambda functions. By leveraging
Nix's reproducibility, you can simplify your development workflows and ensure consistent builds across environments.
