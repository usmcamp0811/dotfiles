# README

I am converting my dotfiles over to Nix. As I learn things I'll add my notes here:


use the `configuration.nix` that we have in this folder instead of the default location at `/etc/nixos/configuration.nix`

```bash
sudo nixos-rebuild switch -I nixos-config=./system/configuration.nix
```

similar thing but for `home-manager`:

```bash
home-manager switch -f ./users/mcamp/home.nix
```

You can build from a Flake with:

```bash
nixos-rebuild build --flake .#
```

*Note: I had to pass `--inpure` and I don't full understand what caused that to be needed.*
