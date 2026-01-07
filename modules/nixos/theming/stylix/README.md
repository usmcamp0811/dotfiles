# Stylix Theming Module

This module provides a unified theming system for your NixOS configuration using [Stylix](https://github.com/danth/stylix).

## Features

Stylix automatically themes:
- **Terminal emulators** (Kitty, Alacritty, etc.)
- **Desktop environments** (Hyprland, KDE, GNOME, etc.)
- **Text editors** (Neovim, Vim, VSCode, etc.)
- **Browsers** (Firefox, Chrome via extensions)
- **Shell prompts** (Starship, etc.)
- **GTK/Qt applications**
- **Boot loader** (GRUB)
- **Virtual console**

## Usage

Enable Stylix in your system configuration:

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "ayu-dark";  # or any base16 theme name
};
```

## Available Themes

Stylix uses [base16 themes](https://github.com/tinted-theming/schemes). Popular options include:

- **Dark themes**: `ayu-dark`, `catppuccin-mocha`, `gruvbox-dark-hard`, `nord`, `tokyo-night-dark`, `dracula`, `onedark`
- **Light themes**: `ayu-light`, `catppuccin-latte`, `gruvbox-light-hard`, `tokyo-night-light`

To browse all available themes, check `/nix/store/*/share/themes/` after installing.

## Configuration Examples

### Basic Configuration with Ayu Dark

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "ayu-dark";
  polarity = "dark";
};
```

### With Custom Wallpaper

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "catppuccin-mocha";
  wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";
};
```

### With Custom Fonts

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "gruvbox-dark-hard";

  fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
    };

    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };

    sizes = {
      applications = 11;
      terminal = 13;
      desktop = 10;
    };
  };
};
```

### With Custom Opacity

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "nord";

  opacity = {
    terminal = 0.9;
    applications = 0.95;
    popups = 0.9;
  };
};
```

### Full Configuration Example

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "ayu-dark";
  wallpaper = ./wallpapers/mountains.png;
  polarity = "dark";

  fonts = {
    monospace = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font Mono";
    };

    sansSerif = {
      package = pkgs.nerd-fonts.fira-sans;
      name = "FiraSans Nerd Font";
    };

    sizes = {
      applications = 12;
      terminal = 13;
      desktop = 10;
      popups = 11;
    };
  };

  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  opacity = {
    terminal = 0.95;
    applications = 1.0;
    popups = 0.9;
  };

  targets = {
    console.enable = true;
    grub.enable = true;
    gtk.enable = true;
  };
};
```

## Integration with Existing Themes

If you want to switch from manually configured themes to Stylix:

1. **Kitty**: Remove manual `themeFile` or `customTheme` settings - Stylix will handle it
2. **Hyprland**: Keep your Hyprland config, Stylix will only theme colors
3. **GTK/Qt**: Stylix will override manual GTK/Qt theme settings
4. **Neovim**: If using nixvim, enable `targets.nixvim.enable = true`

## How to Use Ayu Theme with Stylix

Since you wanted to use the Ayu theme earlier, here's how to do it with Stylix:

```nix
# In your system configuration (e.g., systems/x86_64-linux/gray/default.nix)
fmf.theming.stylix = {
  enable = true;
  theme = "ayu-dark";  # or "ayu-light" for light variant

  # Optional: use the same wallpaper from your hyprpaper config
  wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";

  # Match the font you had in kitty
  fonts.monospace = {
    package = pkgs.nerd-fonts.fira-code;
    name = "FiraCode Nerd Font Mono";
  };

  # Match the opacity you had in kitty
  opacity.terminal = 0.95;
};
```

This will theme Kitty, Hyprland, Waybar, and all other supported applications with the Ayu color scheme!

## Troubleshooting

### Colors not applying

Make sure Stylix is enabled before other theme modules. The module loading order matters.

### Fonts not changing

Ensure the font packages are available and the names match exactly (including "Nerd Font" suffix if applicable).

### Want to exclude certain applications

You can disable specific targets:

```nix
fmf.theming.stylix = {
  enable = true;
  theme = "ayu-dark";

  targets = {
    gtk.enable = false;  # Don't theme GTK apps
  };
};
```

## Resources

- [Stylix Documentation](https://stylix.danth.me/)
- [Base16 Themes Gallery](https://tinted-theming.github.io/base16-gallery/)
- [Stylix GitHub](https://github.com/danth/stylix)
