# Modules

Organize your Nix configurations with ease using the following directory structure:

```
.
├── darwin
├── home
└── nixos
```

This folder is divided into three distinct modules, each serving a specific purpose:

## Darwin

The `darwin` directory is dedicated to MacOS-specific configurations. Place all configurations related to MacOS here to maintain a clean and organized structure.

## Home

The `home` directory is where user-level configurations for `home-manager` belong. Use this space to manage individual user settings, applications, and preferences.

## NixOS

The `nixos` folder is the designated place for system-wide NixOS configurations. Here, you can define and manage settings that apply across the entire system, affecting all users and core functionalities.
