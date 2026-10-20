# Changelog

* [ZFS Tang/Clevis Unlock Module Changelog](CHANGELOG.md) - After HBA card installation (SAS9300), ZFS pools (ChestyPoolr, MotorPool) were failing to auto-unlock, resulting in password prompts during phase 2 boot via systemd-ask-password.

# NixOS Module

* [ZFS Encrypted Root Partition Module for NixOS](README.md) - This NixOS module enables encrypted ZFS root partitions, featuring options for manual and automated unlocking.

# Tutorial

* [TUTORIAL](TUTORIAL.md) - This tutorial explains how to set up an encrypted ZFS root partition on NixOS that auto-unlocks using Clevis.
