# Nix Remote Builder Setup for macOS

This Nix package simplifies the process of setting up a remote builder on macOS by leveraging a Linux
environment via Docker. Since macOS users typically have Docker installed, we can utilize the Linux
VM that Docker uses to run a remote Nix builder. This package is designed to make it easy to build the
Docker image and start it with the necessary secrets.

## Features

- **Easy Docker Image Build**: Quickly build a Docker image with the necessary configuration for Nix
  remote building.
- **Flexible Configuration**: Pass in your SSH authorized key, access tokens, `.netrc` file, and additional
  ports to ensure secure and customizable access to your remote builder.
- **Simple Commands**: Start, stop, and manage your remote builder using straightforward commands.

## Scripts

### 1. `build`

This script builds the Docker image that will be used as the Nix remote builder. You can optionally pass
in your SSH authorized key to be included in the image.

#### Usage:

```bash
nix run .#mac-remote-builder.build -- "your_ssh_authorized_key"
```

- **`your_ssh_authorized_key`**: (Optional) Your SSH public key that will be authorized for SSH access
  to the Docker container. If not provided, a default key from your SSH directory will be used.

### 2. `start`

This script starts the Docker container as the Nix remote builder. It supports named arguments for access
tokens, the SSH port, the `.netrc` file, and additional ports to expose.

#### Usage:

```bash
nix run .#mac-remote-builder.start -- --access-tokens="your_access_tokens" --port=2222
--netrc-file="/path/to/your/.netrc" --additional-ports="444:444,8080:80,9090:9090"
```

- **`--access-tokens="your_access_tokens"`**: (Optional) Access tokens to be included in the `nix.conf`
  file. If not provided, this line will be omitted from the `nix.conf`.
- **`--port=2222`**: (Optional) The SSH port to expose. Defaults to `2222` if not provided.
- **`--netrc-file="/path/to/your/.netrc"`**: (Optional) Path to your `.netrc` file. Defaults to
  `$HOME/.netrc` if not provided.
- **`--additional-ports="444:444,8080:80,9090:9090"`**: (Optional) A list of additional ports to expose
  in the format `host_port:container_port`. Ports should be separated by commas.

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

   - Use the `start` script to start the Docker container with your access tokens, port, `.netrc` file,
     and any additional ports you want to expose.

3. **Stop the Remote Builder**:
   - When you're done, stop the container using the `stop` script.

By using these scripts, you can easily set up a remote Nix builder on your macOS system with minimal hassle.

## Notes

- Ensure that Docker is installed and running on your macOS system before using these scripts.
- The default SSH key provided is for demonstration purposes. Replace it with your own for secure access.
- The `.netrc` file is used for authentication and should be secured accordingly.
- The `--additional-ports` option allows you to expose multiple ports beyond the default SSH port,
  enabling more flexible networking configurations.

Enjoy effortless remote Nix builds on your macOS system!
