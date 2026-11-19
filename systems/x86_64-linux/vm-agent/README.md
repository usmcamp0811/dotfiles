---
type: Host
title: vm-agent
description: Demo of the sandboxed MicroVM used for agentic coding (opencode on self-hosted models, builds on the farm).
resource: ./default.nix
tags: [vm-agent, microvm, agentic-ai, opencode, demo]
---

# vm-agent (demo)

This is a reference copy of the MicroVM I use for agentic coding work. It is here so people
can see how the pieces fit together. **It is not placed on a hypervisor in this flake**
(`host.nix` has no `placement.runsOn`), so nothing here deploys or runs it. The live copy is in
the downstream Campground flake, and the addresses here are this flake's example network.

## The idea

Coding agents run in a throwaway VM that can do real work without reaching the rest of the network:

- **opencode** runs as a shared server inside the VM (`fmf.services.opencode-server`). From a
  workstation you run `opencode-remote` (`fmf.apps.opencode-remote`), which runs `opencode attach`
  against it. Sessions live in the VM, so they survive when the client disconnects.
- **Models are self-hosted**: llama.cpp and Strata (`fmf.services.llama-cpp-client`,
  `fmf.services.strata-client`) behind the LAN reverse proxy. Their API keys come from Vault.
- **Nix never builds in the VM**: `max-jobs = 0`, it substitutes from the niks3 cache, and
  everything else goes to the build farm (`fmf.services.nix-grpc-store.client.useFarm`).
- **The same `~/code`**: the hypervisor user's `~/code` is shared read-write at the same path,
  so the agent edits the real repos rather than a separate clone.
- **The agent's shell** is the same headless home profile as every other machine
  (`homes/x86_64-linux/mcamp@vm-agent`), plus `fmf.tools.agentic-ai`.

## The boundary

| Concern | How it is handled |
| --- | --- |
| Network | On the hypervisor, a bridge filter on the VM's TAP lets it reach the internet, DNS and the LAN reverse proxy, and nothing else on the LAN. Root in the guest cannot change it. This filter is in the downstream flake, not here. |
| Nix | `max-jobs = 0` plus a farm build machine. The agent user is **not** a trusted Nix user, so it cannot change substituters, builders or sandbox settings. |
| Privileges | The agent user has no sudo and is only in `users`. |
| SSH | Only listed public keys. No agent, TCP, stream or X11 forwarding (fmf's ssh client sets `ForwardAgent yes` everywhere, so this matters). |
| Secrets | Only what the `vm-agent` Vault AppRole grants: model API keys, the opencode server password and a farm client certificate (root-only). No SSH private keys, no netrc. |

## Known trade-offs

- The shared `~/code` is a deliberate hole: a misbehaving agent can read and write every repo there.
- A farm client certificate (`ci-*`) has the farm's `trusted` role, so anything that can run
  `nix build` in the VM can use it.
- The opencode server is plain HTTP with basic auth. Put it behind TLS for untrusted networks.
- The agent can still reach the internet, so it can leak whatever it can read (its workspace and the model key).
