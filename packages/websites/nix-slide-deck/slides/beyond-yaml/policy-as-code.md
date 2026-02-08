---
layout: top-title-two-cols
color: dark
columns: is-8
---

:: title ::

# Policy as Code: License Enforcement

:: right ::

<div style="margin-top: 3rem;">

```nix
{
  allowlistedLicenses = with lib.licenses; [
    amd     # AMD proprietary license
    wtfpl   # "Do What the Fuck You Want to" license
  ];

  blocklistedLicenses = with lib.licenses; [
    agpl3Only   # Affero GPL v3 — strong copyleft, network clause
    gpl3Only    # GPL v3 — strong copyleft, common legal concern
  ];

  nixpkgs.config.allowUnfree = false; # Disallow all unfree packages
}
```

</div>

:: left ::

<div style="margin-top: 3rem; font-size: 0.9rem;">

- **Build-time policy enforcement**
  Enforces software license policy before a single bit is built.

- **Allowlist + Blocklist + Unfree filter**
  Accept only trusted licenses, reject flagged ones, and disable unfree packages.

- **Declarative compliance**
  No custom scripts. No CI glue. Just infrastructure that governs itself.

- **YAML can’t do this**
  Would require tooling, enforcement pipelines, and fragile conventions.

</div>

:: default ::

<Admonition title="Strategic Advantage" color="amber-light">
Compliance isn’t an afterthought — in Nix, it’s baked into the build.
</Admonition>
