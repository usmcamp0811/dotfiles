---
okf_version: "0.2"
---

# Architecture

* [Circuit Breaker topology from the flake](CIRCUIT-BREAKER.md) - How the flake's evaluated NixOS configurations become a living, monitored Circuit Breaker topology, which side owns what, and what is and is not verified.

# Design

* [Host model - one record per machine (draft spec)](HOST-MODEL.md) - A single per-host module (identity, interfaces, lifecycle, placement, storage, boot order, DNS, exposure, Vault, topology) and a fleet function that derives leases, DNS, port forwards, Vault roles, MicroVM hosting and boot ordering from it.

# Examples

* [Fleet examples - copy-paste records for VMs and networking](FLEET-EXAMPLES.md) - Ready-to-copy host, storage and attachment records for common cases - networking only, MicroVMs only, both together, two interfaces, VLANs, Vault, standby and retired hosts, macvtap, existing data folders and port forwards.

# Guide

* [Nix Build Farm (fmf.services.nix-grpc-store)](BUILD-FARM.md) - A generic guide to the build farm module in this flake: what it does, how to wire it into a host configuration, and what has to exist in Vault before it will run.
* [nixpkgs-multiverse: pinning one package version without a new flake input](NIXPKGS-MULTIVERSE.md) - This flake now has nixpkgs-multiverse as an input, and a small library helper, lib.fmf.multiversePackage, that resolves it.
* [Open Knowledge Format in fmf](OKF.md) - How fmf's docs, modules and systems directories are OKF v0.2 bundles, and how to keep them conformant.
* [Vault AppRoles - one role per host, least-privilege policies](VAULT-APPROLES.md) - How AppRoles are declared in Nix next to policies, the one-role-per-host naming rule, how to audit live roles against the flake, and the phased plan for replacing the broad campground policy with generated per-service policies.
* [Video Lock Screen Configuration (fmf module)](VIDEO-LOCK-SCREEN-FMF.md) - This document describes the video lock screen feature in the fmf flake.
* [Wazuh in fmf-flake](wazuh.md) - Downstream flakes can pin your historical Wazuh behavior by pinning your flake revision in inputs.

# Note

* [AWS EC2 instance from a local VHD](ec2-notes.md) - Steps to create an AWS EC2 instance from a local VHD image, uploaded through an S3 bucket.
* [How Nix Works](nix-sequence-diagram.md) - This diagram provides a high-level overview of how a Nix script is processed.
* [LevelUp Your Nix](LevelUp.md) - Installing Nix and enabling flakes, then starting from a template.
* [Loops in Nix: A Comprehensive Guide](nix-loops.md) - Nix is a functional programming language, meaning it does not have traditional imperative loops like Python or Julia.

# Reference

* [Circuit Breaker inventory format (schema v1)](CIRCUIT-BREAKER-INVENTORY.md) - The versioned, Circuit-Breaker-independent document the flake exporter produces and the reconciler consumes.
* [How to Use Hashicorp Vault for Managing Secrets on NixOS](SECRETS.md) - This guide will walk you through the process of securely providing secrets to a NixOS system using Hashicorp Vault.
* [Service Dependency Map](SERVICE-DEPENDENCY-MAP.md) - Complete mapping of all services across the infrastructure with dependency relationships.

# Runbook

* [Circuit Breaker runbook](CIRCUIT-BREAKER-RUNBOOK.md) - Install, first-run setup, daily operation, agents, discovery, backup and restore, secret rotation, upgrade and rollback for the flake-driven Circuit Breaker.
* [CVE-2026-39860 Fix for fmf-flake](CVE-2026-39860-MITIGATION.md) - Mitigation for CVE-2026-39860 in fmf-flake by upgrading to Nix 2.34.5.
* [Fleet runbook - day-to-day operations](FLEET-RUNBOOK.md) - Step-by-step procedures for a flake that uses fmf.host records and fleet - the daily loop, adding a host or MicroVM, changing an address, exposing a port, moving, retiring and converting a VM, generated tap rules, a CI drift check, upgrading fmf and rolling back.
* [Quick Start: Patching CVE-2026-39860](CVE-2026-39860-QUICKSTART.md) - Your fmf-flake has been updated to use Nix 2.34.5 (patched) instead of the vulnerable Nix 2.31.3.
* [Reformat & Install NixOS](Install.md) - Reformat a drive and install NixOS from a live USB, with BTRFS or ZFS partitioning.
* [Vault runbook - day-to-day operations](VAULT-RUNBOOK.md) - Step-by-step procedures for working with Vault in an fmf flake - the mental model, checking health, adding a host, changing what a host can read, narrowing or removing a policy, replacing and retiring a role, rotating credentials, and recovering when something breaks.

# Test Guide

* [Circuit Breaker tests](CIRCUIT-BREAKER-TESTING.md) - Which checks exist for the Circuit Breaker integration, what each proves, how to run them, and how to extend them.

# Troubleshooting

* [Circuit Breaker troubleshooting](CIRCUIT-BREAKER-TROUBLESHOOTING.md) - Exit codes, symptoms and fixes for the Circuit Breaker server, reconciler, git-driven sync, agents and monitors.
* [Fleet troubleshooting - errors, warnings and symptoms](FLEET-TROUBLESHOOTING.md) - What each fleet error and warning means and how to fix it, plus the common ways a flake, a MicroVM or the generated files go wrong - messages quoted from real runs.
* [MicroVM boot and configuration pitfalls](MICROVM-TROUBLESHOOTING.md) - Failures we hit bringing up fmf/Campground MicroVMs (stale store overlay, emergency mode, duplicate option definitions, surprise sudo and NetworkManager) with the check and the fix for each.

# Tutorial

* [Getting started with the fleet (fmf.host records and fleet)](FLEET-GETTING-STARTED.md) - A first-time walk-through for a downstream flake - what a host record is, the one-time flake wiring, your first record, running fleet, and which of the two follow-on tutorials (MicroVMs, networking, or both) to read next.
* [Leases, DNS and port forwards from records](FLEET-TUTORIAL-NETWORK.md) - Describe machines once in host records and let fleet generate the DHCP reservations, DNS names and router port forwards, then wire those files into a plain NixOS gateway, fmf's router module, or AdGuard - written for someone who has not used the host model before.
* [MicroVMs from records](FLEET-TUTORIAL-VMS.md) - Describe a hypervisor and two MicroVMs with host records, let fleet derive the VM list, shared directories, start order and network rules, and bring the VMs up - written for someone who has not used the host model before.
