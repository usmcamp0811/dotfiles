# Install NixOS

Generate your `hardware.nix` and create your new system configs by running:

```
nixos-generate-config --root /mnt
git clone https://gitlab.com/usmcamp0811/dotfiles.git /mnt/config
```

Make your new system under the correct architecture (likely `x86_64-linux`). If your new system was to be named `carey` then you would:

```
mkdir /mnt/config/systems/x86_64-linux/carey
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/config/systems/x86_64-linux/carey/hardware.nix
cp /mnt/config/systems/x86_64-linux/template /mnt/config/systems/x86_64-linux/carey/default.nix
```

You will need to make some modifications to `/mnt/config/systems/x86_64-linux/carey/default.nix`, but don't add things that need secrets from Vault, because we don't have our our approle setup yet and I don't recommend doing that yet.

You will need to `git add` the new config files so the Flake can see them.

If you are feeling lucky you can install my flake first but I've had spotty luck getting the system to boot first time when I do this. 

```
nixos-install --flake /mnt/config#carey
```

So what I suggest is you do:

```
nixos-install
nixos-enter
nixos-rebuild boot --flake /config#carey
```
If all went as expected then you should be able to reboot and boot into your new config. If the flake config doesn't boot then just run:

```
nixos-rebuild switch --flake /config#carey
```

You should then have the flake config which you can then tweak as you wish.

#### TODO:

- I want to automate this more. Disko is something I want to use but its unclear to me how to do ZFS or BTRFS encrypted with it, and I've had issues being able to boot after using it. 
- I would like to automate the addition of new systems. I think I could probably just write a shell script or something that gets added to the flake and can be run. 
- It would be great to just be able to install from the flake directly, so I probably just need to see what causes the issues with booting this way.
