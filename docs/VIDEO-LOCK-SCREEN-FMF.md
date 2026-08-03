# Video Lock Screen Configuration (fmf module)

This document describes the video lock screen feature in the fmf flake.

## Overview

The `fmf.desktop.addons.swaylock` module now supports video backgrounds using `swaylock-plugin` and `mpvpaper`. When enabled, the lock screen will randomly select and play a video from a configured directory.

## Configuration

### System-level (NixOS)

Enable video background support in your system configuration:

```nix
fmf.desktop.addons.swaylock = {
  enable = true;
  useVideoBackground = true;
};
```

This will:
- Install `swaylock-plugin` and `mpvpaper` packages
- Configure PAM for `swaylock-plugin`
- Keep `swaylock-effects` as a fallback

### Home-level (home-manager)

Configure the video directory in your home configuration:

```nix
fmf.desktop.addons.swaylock = {
  useVideoBackground = true;
  videoDirectory = "\${config.home.homeDirectory}/Videos";  # default
};
```

## Options

### `fmf.desktop.addons.swaylock.useVideoBackground`
- **Type**: boolean
- **Default**: `false`
- **Description**: Whether to use video backgrounds for the lock screen

### `fmf.desktop.addons.swaylock.videoDirectory`
- **Type**: string
- **Default**: `"${config.home.homeDirectory}/Videos"`
- **Description**: Directory containing lock screen videos

## Video Requirements

Place video files in the configured directory (default: `~/Videos`):

- **Supported formats**: `.mp4`, `.mkv`, `.webm`
- **Recommended**: MP4 with H.264 encoding
- **Resolution**: Match or exceed your display resolution
- **File size**: Keep under 100MB for smooth playback
- **Loop quality**: Choose videos with seamless loops for best effect

## How It Works

When `useVideoBackground` is enabled:

1. A `video-lock` script is added to your `$PATH`
2. The script randomly selects a video from your configured directory
3. It launches `swaylock-plugin` with `mpvpaper` playing the video
4. If no videos are found, it falls back to `swaylock-effects`

The `video-lock` command is automatically used in:
- Hyprland lock keybinding (`SUPER + L`)
- swayidle events (before-sleep, lock)
- swayidle timeouts (after 15 minutes of inactivity)

## Example Usage

### Full Configuration

```nix
# systems/x86_64-linux/gray/default.nix
fmf.desktop.addons.swaylock = {
  enable = true;
  useVideoBackground = true;
};

# homes/x86_64-linux/mcamp@gray/default.nix
fmf.desktop.addons.swaylock = {
  useVideoBackground = true;
  videoDirectory = "\${config.home.homeDirectory}/Videos";
};
```

### Add Videos

```bash
mkdir -p ~/Videos
# Copy your video files
cp /path/to/cool-video.mp4 ~/Videos/
```

### Manual Lock

```bash
# Lock with video background
video-lock

# Or use the keybinding: SUPER + L
```

## Troubleshooting

### No videos play
- Check that videos exist: `ls ~/Videos/*.{mp4,mkv,webm}`
- Verify video-lock script is in PATH: `which video-lock`
- Test a video manually: `mpv ~/Videos/your-video.mp4`

### Falls back to static lock screen
- This happens when no videos are found in the directory
- Check the configured `videoDirectory` path
- Ensure videos have supported extensions

### Lock screen doesn't unlock
- Switch to TTY: `Ctrl+Alt+F2`
- Kill the lock process: `pkill swaylock-plugin`
- Switch back: `Ctrl+Alt+F1` or `F7`

### Performance issues
- Use lower resolution videos
- Reduce video bitrate
- Enable hardware acceleration in mpv (auto-detected)

## Integration

The video lock feature integrates with:

- **Hyprland**: Automatic keybinding update (`SUPER + L`)
- **swayidle**: Automatic timeout and event integration
- **swaylock-effects**: Fallback when no videos available

## Security Note

⚠️ `swaylock-plugin` is experimental software. Always keep a TTY recovery option available:
- `Ctrl+Alt+F2` to switch to TTY
- `pkill swaylock-plugin` to kill the lock screen
- `Ctrl+Alt+F1` or `F7` to return to GUI

## See Also

- [Video Lock Screen Background Guide](/docs/VIDEO-LOCK-SCREEN.md) - Detailed implementation guide
- [swaylock-plugin GitHub](https://github.com/mstoeckl/swaylock-plugin)
- [mpvpaper GitHub](https://github.com/GhostNaN/mpvpaper)
- [Wayland Session Lock Protocol](https://wayland.app/protocols/ext-session-lock-v1)
