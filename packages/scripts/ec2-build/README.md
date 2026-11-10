---
type: Reference
title: ec2-build (throwaway aarch64 EC2 remote builder)
description: Command that creates an aarch64 NixOS instance on EC2, runs a Nix command with it as the remote builder for aarch64-linux, and destroys it afterwards.
tags: [ec2-build, aws, remote-builder, aarch64, terranix]
status: draft
---

# ec2-build

```bash
nix run .#ec2-build -- --env-file ~/.config/ec2-build.env -- \
  nix build .#nixosConfigurations.pikvm.config.system.build.toplevel
```

Creates one Graviton instance from the official NixOS AMI, points the command's `nix` at it as an
`ssh-ng` builder for `aarch64-linux`, and destroys the instance, its key pair and its security group
when the command ends (also on failure and Ctrl-C). The exit status is the command's.

The guide, with requirements, the env file, safety nets and troubleshooting, is
[docs/EC2-BUILD.md](../../../docs/EC2-BUILD.md). `ec2-build --help` lists every setting.

| File | What it is |
| --- | --- |
| `terraform.nix` | The terranix module: key pair, security group, instance; per-run values are variables. |
| `ec2-build.sh` | The script. `@TF_CONFIG@` is replaced with the generated JSON at build time. |
| `default.nix` | `writeShellApplication`, with OpenTofu and the AWS provider bundled (no registry download). |
