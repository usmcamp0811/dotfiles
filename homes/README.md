# Stand-alone Home Manager Configurations

Manage your Nix system configurations with ease using stand-alone home-manager. This guide provides instructions for both local users and multi-user or LDAP systems.

## Local Users

This section outlines how to set up `home-manager` configurations for individual systems.

### Directory Structure

Place your configurations in folders following this pattern: `./<system architecture>/<user>@<host>`.

### Example Configuration

Here's a minimal example that sets up a local user's `home-manager`:

```nix
{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli-apps = {
      zsh = enabled;
      home-manager = enabled;
    };
    
    tools = {
      git = enabled;
      direnv = enabled;
    };
  };
  home.stateVersion = "23.05";
}
```

This configuration will be automatically installed when you build the corresponding system. The enabled apps and other configurations are drawn from the `../modules/home` directory.

**Note:** The above configuration is currently limited to single-user systems.

## Multi-User / LDAP System

For systems with multiple users or LDAP integration, follow the instructions below.

### Directory Structure

Create a folder for your user following a similar pattern as above: `./<system architecture>/<user>@ldap_user`. Users configured in this way will not be built with the system.

### Example Configuration for an LDAP User

Here's a minimal example for an LDAP user:

```nix
{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = "mcamp";
    };

    cli-apps = {
      zsh = enabled;
      home-manager = enabled;
    };
    
    tools = {
      git = enabled;
      direnv = enabled;
    };
  };
  home.stateVersion = "23.05";
}
```

### Activation

Run the following command, which is analogous to `home-manager switch`:

```bash
nix run .\#homeConfigurations.mcamp@ldap_user.activationPackage
```

**Important:** Ensure that the system to which the user belongs is not the same as any other system in the config. Otherwise, errors may occur.
