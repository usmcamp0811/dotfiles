# Nix Remote Builder Setup for macOS

This Nix package simplifies the process of setting up a remote builder on macOS by leveraging a Linux environment via Docker. Since macOS users typically have Docker installed, we can utilize the Linux VM that Docker uses to run a remote Nix builder. This package is designed to make it easy to build the Docker image and start it with the necessary secrets.

## Features

- **Easy Docker Image Build**: Quickly build a Docker image with the necessary configuration for Nix remote building.
- **Flexible Configuration**: Pass in your SSH authorized key, access tokens, and `.netrc` file to ensure secure access to your remote builder.
- **Simple Commands**: Start, stop, and manage your remote builder using straightforward commands.

## Scripts

### 1. `build`

This script builds the Docker image that will be used as the Nix remote builder. You can optionally pass in your SSH authorized key to be included in the image.

#### Usage:

```bash
nix run .#mac-remote-builder.build -- "your_ssh_authorized_key"
```

- **`your_ssh_authorized_key`**: (Optional) Your SSH public key that will be authorized for SSH access to the Docker container. If not provided, a default key will be used.

### 2. `start`

This script starts the Docker container as the Nix remote builder. It allows you to specify access tokens for the `nix.conf` file, the port to expose for SSH, and a custom `.netrc` file for authentication.

#### Usage:

```bash
nix run .#mac-remote-builder.start -- "your_access_tokens" 2222 "/path/to/your/.netrc"
```

- **`your_access_tokens`**: (Optional) Access tokens to be included in the `nix.conf` file. If not provided, this line will be omitted from the `nix.conf`.
- **`2222`**: (Optional) The SSH port to expose. Defaults to `2222` if not provided.
- **`/path/to/your/.netrc`**: (Optional) Path to your `.netrc` file. Defaults to `$HOME/.netrc` if not provided.

### 3. `stop`

This script stops the Docker container running the Nix remote builder.

#### Usage:

```bash
nix run .#mac-remote-builder.stop
```

### 4. `readme`

This script prints out this README file to help you understand the usage of the package.

#### Usage:

```bash
nix run .#mac-remote-builder
```

## How to Get Started

1. **Build the Docker Image**:

   - Run the `build` script to build the Docker image with your SSH key.

2. **Start the Remote Builder**:

   - Use the `start` script to start the Docker container with your access tokens, port, and `.netrc` file.

3. **Stop the Remote Builder**:
   - When you're done, stop the container using the `stop` script.

By using these scripts, you can easily set up a remote Nix builder on your macOS system with minimal hassle.

## Notes

- Ensure that Docker is installed and running on your macOS system before using these scripts.
- The default SSH key provided is for demonstration purposes. Replace it with your own for secure access.
- The `.netrc` file is used for authentication and should be secured accordingly.

Enjoy effortless remote Nix builds on your macOS system!
