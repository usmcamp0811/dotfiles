# ZSH Configuration with Campground CLI Apps

This Nix configuration file provides a robust setup for ZSH within the Campground CLI Apps framework. It includes features like command completion, autosuggestions, syntax highlighting, and integration with Oh My Zsh.

## Directory Structure

The configuration organizes ZSH themes and settings within the `.config/shell/zsh` directory.

## Features

### ZSH Enhancements

- **Command Completion:** Enhances the command-line experience with intelligent suggestions.
- **Autosuggestions:** Offers real-time command suggestions based on your command history.
- **Syntax Highlighting:** Adds color to your command line for better readability.
- **Oh My Zsh Integration:** Includes the popular Oh My Zsh framework with the "fzf" plugin.

### User Secrets Integration

One of the standout features of this configuration is the integration with user secrets, specifically with HashiCorp's key-value store. Here's how it works:

```nix
campground.services.user-secrets = {
  enable = true;
  users = {
    mcamp = {
      files = [
        "passwords"
      ];
    };
  };
};
```

By defining the `passwords` key, the system will automatically source shell variables containing passwords or other secret values into the shell environment. This seamless integration ensures that your sensitive information is handled securely and efficiently.

## Files Included

- `00-main.zsh`: Main ZSH configuration.
- `fino.zsh-theme`: Custom ZSH theme.
- `git.zsh`: Git-related configurations.
- `prompt_info_functions.zsh`: Functions for customizing the prompt.
- `spectrum.zsh`: Color configurations.
- `theme-and-appearance.zsh`: Theme and appearance settings.

## Usage

To utilize this configuration, include it in your Nix system setup and adjust the user-specific settings as needed. Refer to the provided code for detailed configuration options and customization.

