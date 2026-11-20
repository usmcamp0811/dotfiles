---
type: NixOS Module
title: Crystal Forge MCP client (fmf.services.crystal-forge-mcp-client)
description: Adds a Crystal Forge MCP server to a user's OpenCode, with its access token rendered from Vault as a runtime credential.
resource: ./default.nix
tags: [services, crystal-forge, mcp, opencode, agentic-ai, vault]
generated: { by: claude-agent/opus-5-5, at: 2026-11-19T23:30:00-06:00 }
status: draft
---

# Crystal Forge MCP client

Gives a user's OpenCode the read-only MCP endpoint of a Crystal Forge server
(`services.crystal-forge.server.mcp`). It is built like `llama-cpp-client` and
`strata-client`: one credential file, delivered through the existing user-secrets path, plus
the OpenCode configuration.

## What it does

- **opencode.json** (home-manager, `fmf.tools.agentic-ai.mcp`): a remote MCP server named
  `crystal-forge` (`name`) at `url`, with `oauth = false` and
  `Authorization: Bearer {env:CF_MCP_TOKEN}`. The token itself is never in the Nix store.
- **The `opencode` command** exports `CF_MCP_TOKEN` (`envVar`) from `tokenFile` when it starts
  (`fmf.tools.agentic-ai.runtimeEnvFiles`).
- **`fmf.services.opencode-server`** gets it too: its `environmentFiles` default includes the
  credential of every enabled client (llama.cpp, Strata, this one). A host that sets
  `environmentFiles` itself replaces that default and must list `CF_MCP_TOKEN` as well.
- **Vault** (`vault.enable`, default on): adds `crystal_forge_mcp_pat` to
  `fmf.services.user-secrets.users.<user>` and renders it from `vault.path` / `vault.field` into
  `/var/lib/vault/users/<user>/crystal_forge_mcp_pat`, readable by that user. `vault-access`
  adds the path to the host's generated `svc-user-secrets-<user>--...` policy.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `enable` | `false` | Turn it on. |
| `user` | `fmf.user.name` | Whose OpenCode, and who can read the token. Must exist. |
| `url` | `null` | Required. The server's MCP endpoint, `https://`. |
| `name` | `crystal-forge` | Name of the server in OpenCode (`opencode mcp list`). |
| `envVar` | `CF_MCP_TOKEN` | Variable the token is passed in. |
| `tokenFile` | `/var/lib/vault/users/<user>/crystal_forge_mcp_pat` | Runtime file. Keep the default with Vault. |
| `vault.enable` | `true` | Render the token from Vault. Off: provide `tokenFile` yourself. |
| `vault.path` | `""` | Vault API path, with `/data/` for KV v2 (asserted). |
| `vault.field` | `mcp_pat` | Field holding the token. |
| `vault.kvVersion` | `2` | KV engine version. |

## Things to know

- **Write the secret before deploying.** The token is one file of the shared `user-secrets-<user>`
  render: if `vault.path` does not exist yet, that render fails and the user's other files
  (llama.cpp and Strata keys, ...) are not delivered either.
- **The token belongs to the user, and so to any agent running as that user.** Anything the agent
  runs can read it and call the MCP endpoint with it. Crystal Forge's MCP endpoint is read-only,
  but the token sees whatever its owner can see there. Use a token of an account scoped for that.
- **Rotation:** create a new token in Crystal Forge (Profile, Access tokens), write it to Vault;
  user-secrets re-renders the file. `opencode` picks it up on the next start; restart
  `opencode-server` for the server.
- Tokens live at most `services.crystal-forge.server.accessTokens.maxLifetimeDays` (90 by
  default), so expect to rotate.
- The OpenCode entry uses the 1.x layout (servers directly under `mcp`).

## Example

```nix
fmf.services.crystal-forge-mcp-client = {
  enable = true;
  url = "https://crystal-forge.example.com/mcp";
  vault.path = "secret/example/data/crystal-forge";
};
```

Check, as the user: `opencode mcp list` should show `crystal-forge` connected.
