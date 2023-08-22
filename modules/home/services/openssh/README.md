# OpenSSH Configuration Module

This Nix module provides a flexible and customizable way to configure OpenSSH support within the Campground environment. It allows you to manage authorized keys, port settings, and other host configurations.

## Features

- **Enable OpenSSH Support**: Toggle OpenSSH support on or off.
- **Authorized Keys Management**: Define a list of public keys to be authorized.
- **Custom Port Configuration**: Set a custom port for OpenSSH to listen on.
- **Manage Other Host Configurations**: Optionally add other host configurations to the SSH config.
- **GPG Agent Forwarding**: Support for forwarding GPG agents between hosts.
- **Zsh Shell Aliases**: Define custom aliases for SSH connections.

## Options

- `enable`: Whether or not to configure OpenSSH support. Default is `false`.
- `authorizedKeys`: A list of public keys to apply. Default includes a predefined key.
- `port`: The port to listen on (in addition to 22). Default is `2222`.
- `manage-other-hosts`: Whether or not to add other host configurations to SSH config. Default is `true`.

## Usage

Include this module in your Nix configuration and customize the options as needed. Here's an example:

```nix
{
  campground.services.openssh.enable = true;
  campground.services.openssh.authorizedKeys = [ "your-ssh-key" ];
  campground.services.openssh.port = 2222;
}
```
