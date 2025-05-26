---
theme: ./themes/slidev-theme-neversink
class: text-left
color: dark
---

# Remote Linux Builder on macOS

How to build and deploy Linux systems from a Mac using Nix and a local VM.

---
layout: top-title
color: dark
class: text-sm
---

:: title ::

# Step 1: Start Remote Builder

:: content ::

<div class="text-sm">
<p><b>What is a Remote Builder?</b></p>
<p>A remote builder is another machine that performs Nix builds on behalf of your local system. In our case, it’s a lightweight Linux virtual machine running on your macOS host. This allows you to build Linux derivations—even if you're on macOS—without cross-compiling.</p>

<p>Using a remote builder helps when:</p>
<ul>
  <li>The package can’t be cross-compiled</li>
  <li>You want to ensure compatibility with Linux</li>
  <li>You want to isolate builds from your host system</li>
</ul>

<p><b>Step 1: Run the builder VM</b></p>

```sh
nix run nixpkgs#darwin.Linux-builder
```

<p>This command downloads and runs a minimal NixOS VM with QEMU. It’s configured to act as a remote build machine and integrates with your local Nix daemon once you set up the right configuration.</p>

<p>The VM is started automatically and runs quietly in the background, ready to accept build tasks delegated by Nix.</p>
</div>

---
layout: top-title
color: dark
class: text-sm
---

:: title ::

# Step 2: Update `nix.conf`

:: content ::

<div class="text-sm">

<p>To use the Linux builder VM, your local Nix daemon must trust you and know how to connect to the VM. The file to edit is:</p>

```sh
/etc/nix/nix.conf
```

_This file controls global Nix behavior on macOS, including who is allowed to invoke builds and which machines can do builds._

**Below is the change needed:**

```ini
build-users-group = nixbld
extra-trusted-users = @admin
builders = ssh-ng://linux-builder x86_64-linux,aarch64-linux /etc/nix/machines
```

**Explanation:**

- `build-users-group = nixbld` allows secure sandboxed builds
- `extra-trusted-users = @admin` ensures admin group can initiate privileged builds
- `builders = ...` enables remote builds through the VM running locally

</div>

---
layout: top-title
color: dark
class: text-sm
---

:: title ::

# Step 3: SSH Config

:: content ::

<div class="text-sm">

<p>To allow your local Nix daemon to communicate with the remote builder VM, SSH access must be properly configured. This is how Nix securely delegates builds to another machine.</p>

<p>Instead of typing out long SSH commands, we create a named alias in the SSH config file. This alias will be used in your <code>nix.conf</code> to reference the builder cleanly.</p>

<p>The SSH config also ensures that the correct identity (SSH key) is used and the right port is targeted—since the VM likely runs on a forwarded port, not the default 22.</p>

<p><b>Step 3: Add SSH alias</b></p>

```
# ~/.ssh/config
Host linux-builder
  HostName 127.0.0.1
  Port 22xx  # Replace with actual builder port
  User root
  IdentityFile ~/.config/nixpkgs/linux-builder/id_ed25519
```

<p>Once this is set, Nix can use the builder transparently via the alias <code>linux-builder</code>.</p>

</div>

---
layout: side-title
color: dark
class: text-sm
titlewidth: is-5
---

:: title ::

# Now with `nix-darwin`

:: content ::

- If you're managing your macOS system declaratively using `nix-darwin`, you can enable the Linux builder directly from your Nix configuration.

- This makes it easier to integrate the builder into your system state and track changes over time. You also don’t need to manually edit `nix.conf` or start the VM explicitly—`nix-darwin` handles that for you.

- Builder config can be versioned and shared, making team setups reproducible and consistent.

- Automatically restarts the VM if it crashes or your machine reboots, keeping it available for builds.

---
layout: top-title
color: dark
columns: is-6-6
---

:: title ::

# Config Changes

:: default ::

To enable the remote Linux builder declaratively using `nix-darwin`, add this to your configuration:

```nix
{
  nix = {
    linux-builder.enable = true;
    settings.trusted-users = [ "@admin" ];
  };
}
```

Then apply the changes with:

```sh
darwin-rebuild switch
```

---
layout: center
color: dark
---

# What does this do?

- Automatically launches and manages the builder VM
- Configures `nix.conf` with builder support
- Creates an SSH alias for communication
- Makes setup repeatable and declarative

It’s the fastest way to get remote builds working on macOS using Nix.

---
layout: top-title
color: dark
class: text-sm
---

:: title ::

# Tuning the Builder

:: content ::

<div class="text-sm">

You can customize the Linux builder VM with additional options for more performance:

```nix
{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config.virtualisation = {
      darwin-builder = {
        diskSize = 40960; # 40 GB
        memorySize = 8192; # 8 GB
      };
      cores = 6;
    };
  };
}
```

This makes the builder more capable for large or parallel builds by tuning disk size, memory, and CPU allocation.

</div>

---
layout: top-title
color: dark
class: text-sm
---

:: title ::

# Testing the Builder

:: content ::

<div class="text-sm">

You can test the Linux builder with a simple derivation:

```sh
nix build --impure --expr 'with import <nixpkgs> { system = "aarch64-linux"; }; runCommand "foo" {} "uname -a > $out"'
cat result
```

If the output shows a Linux kernel version, then your builder is working.

</div>

---
layout: top-title
color: dark
---

:: title ::

# Deploy to Linux Machine

:: content ::

Once you're building for Linux, you can deploy to a remote NixOS machine with:

```sh
nixos-rebuild switch \
  --fast \
  --target-host build02 \
  --flake .#build02 \
  --use-remote-sudo \
  --use-substitutes
```

Make sure `nixos-rebuild` is available. If you're not using nix-darwin to install it, you can run:

```sh
nix shell nixpkgs#nixos-rebuild
```

---
layout: side-title
color: dark
class: text-sm
---

:: title ::

# Conclusion

:: content ::

You now have a powerful, isolated Linux build environment—even on macOS—with support for deployment to real Linux systems.

- Local Linux builder on macOS
- Declarative setup via `nix-darwin`
- Seamless remote builds and deploys
- QEMU Rosetta support is still pending

While this guide focused on using a local Linux VM, Nix also supports remote builders over SSH. These can be other physical machines, cloud instances, or any device reachable on your network. The same configuration approach applies.
