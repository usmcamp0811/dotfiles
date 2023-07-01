# README

I am converting my dotfiles over to Nix. As I learn things I'll add my notes here:


use the `configuration.nix` that we have in this folder instead of the default location at `/etc/nixos/configuration.nix`

```bash
sudo nixos-rebuild switch -I nixos-config=./system/configuration.nix
```
