# Wazuh in fmf-flake

This flake now provides:

- `packages.applications.wazuh-agent` (`pkgs.fmf.wazuh-agent`)
- `packages.applications.wazuh-manager` (`pkgs.fmf.wazuh-manager`)
- `modules.nixos.services.wazuh-agent`
- `modules.nixos.services.wazuh-manager`

## Basic usage

```nix
{
  fmf.services.wazuh-manager.enable = true;

  # On clients
  fmf.services.wazuh-agent = {
    enable = true;
    managerAddress = "10.8.0.10";
  };
}
```

## Update workflow

Wazuh packaging is centralized in:

- `packages/applications/wazuh/mk-wazuh.nix`

To update versions, edit these args in that file (or override from your system):

- `version`
- `srcHash`
- `dependencyVersion`
- `dependencyHashes`
- `wazuhHttpRequestRev`
- `wazuhHttpRequestHash`

## Pinning for downstream users

Downstream flakes can pin your historical Wazuh behavior by pinning your flake revision in `inputs`.

That gives reproducible historical package+module behavior even after you move to newer Wazuh versions on `main`.
