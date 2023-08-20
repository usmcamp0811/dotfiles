# Qtile Configuration Module for Nix

This Nix module provides a configurable setup for Qtile, a tiling window manager. It allows users to enable or disable the Qtile configuration, set a wallpaper, configure Redshift with latitude and longitude, and set a screen lock time.

## Options

- `enable`: Whether or not to turn on Qtile configuration (default: `false`).
- `wallpaper`: Name of the wallpaper to set (default: `"hsv-saturnV.png"`).
- `lat-lon`: Latitude and longitude for Redshift (default: `"34.6503:86.7757"`).
- `lock-time`: Time in minutes to wait to lock the screen (default: `"10"`).

## Usage

To use this module, include it in your Nix configuration and set the desired options. Here's an example:

```nix
campground.desktop.qtile = {
        enable = true;
        wallpaper = "hsv-saturnV.png";
        lat-lon = "34.6503:86.7757";
        lock-time = "5";
      };
```

## Dependencies

This module relies on the following packages:

- `redshift`: For adjusting the color temperature of the screen.
- `xautolock`: For automatically locking the screen.
- `feh`: For setting the wallpaper.
