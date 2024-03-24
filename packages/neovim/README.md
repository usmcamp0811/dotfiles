# Campground NeoVim Configuration in Nix

This package is my NeoVim configuration. While the configuration is mostly functional, some features are still under development or may contain bugs.

## Getting Started

To use this configuration, follow the steps below:

### Installing Nix (If Not Installed)
```sh
sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
curl -L https://nixos.org/nix/install | sh
source /home/$USER/.nix-profile/etc/profile.d/nix.sh
```

### Running the Configuration
```sh
nix run gitlab:usmcamp0811/dotfiles#neovim
```

