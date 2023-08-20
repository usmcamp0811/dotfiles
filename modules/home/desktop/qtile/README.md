# Nix Module for Qtile Configuration

Configure Qtile, a tiling window manager, with this Nix module. Customize wallpaper, Redshift settings, and screen lock time.

## Options

- `enable`: Enable Qtile configuration (default: `false`).
- `wallpaper`: Wallpaper name, located in `~/Pictures/wallpapers` (default: `"hsv-saturnV.png"`).
- `lat-lon`: Redshift latitude and longitude (default: `"34.6503:86.7757"`).
- `lock-time`: Screen lock delay in minutes (default: `"10"`).

## Usage

Include in your user configuration and set options:

```nix
campground.desktop.qtile = {
  enable = true;
  wallpaper = "hsv-saturnV.png";
  lat-lon = "34.6503:86.7757";
  lock-time = "5";
};
```

## Dependencies

- `redshift`: Adjusts screen color temperature.
- `xautolock`: Auto-locks the screen.
- `feh`: Sets the wallpaper.
