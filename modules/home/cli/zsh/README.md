# ZSH Configuration

This Nix module offers a comprehensive setup for ZSH. It incorporates features like command completion, autosuggestions, syntax highlighting, and Oh My Zsh integration.

## Directory Structure

The configuration is organized as follows:

```
.
├── default.nix
├── fino-theme
│   ├── fino.zsh-theme
│   ├── git.zsh
│   ├── prompt_info_functions.zsh
│   └── spectrum.zsh
└── README.md
```

The `fino-theme` directory contains theme-related files.

## Features

### ZSH Enhancements

- **Command Completion:** Provides intelligent suggestions as you type.
- **Autosuggestions:** Suggests commands based on your history.
- **Syntax Highlighting:** Colors your command line for readability.
- **Oh My Zsh Integration:** Enables the popular Oh My Zsh framework with the "fzf" plugin.
- **Vim Bindings:** Vim key bindings are enabled, allowing you to navigate and edit the command line using familiar Vim commands.

### User Secrets Integration

If the `user-secrets` service is enabled with a `passwords` file for the user, the shell will automatically source the file, making the secrets available in the shell environment.

*Example `user-secrets` configuration:*

```nix
campground.services.user-secrets = {
  enable = true;
  users = {
    mcamp = {
      files = ["passwords"];
    };
  };
};
```

### Extra Source Files

You can also specify additional files to be sourced outside this configuration by using the `extraSource` option. Provide the absolute paths to the files you wish to include.

*Example configuration:*

```nix
cli = {
  zsh = {
    enable = true;
    extraSource = [
      "~/example-file-to-source"
      "~/.secrets"
    ];
  };
};
```

## Usage

To use this module, include it in your Nix system setup and modify the user-specific settings as required. The provided code contains detailed configuration options for customization.

