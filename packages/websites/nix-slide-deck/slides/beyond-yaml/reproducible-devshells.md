---
layout: top-title-two-cols
color: dark
columns: is-6
class: text-sm
---

:: title ::

# Reproducible Dev Environments, by Default

:: left ::

```nix
{ mkShell, pkgs, ... }:
mkShell {
  packages = with pkgs; [
    (
      python3.withPackages (ps:
        with ps; [
          numpy
          pandas
          requests
        ])
    )
    openjdk
    nodejs
    git
    postgresql
    azure-cli
  ];

  shellHook = ''
    echo "DevShell ready to go."
  '';
}
```

:: right ::

<div style="font-size: 0.95rem;">

- **Same result everywhere** — dev, CI, prod
- **No `apt install`**, no “setup” scripts, no drift
- **No README spelunking** — run `nix develop` and go
- **Your devshell _is_ your build environment**
  If it works locally, it works in CI
- **No container juggling** — no volumes, no bind mounts, no mystery state
- **Declare what you need, Nix handles the rest**

</div>
<AdmonitionType type="info">
Stop shipping “how to run this” docs — start shipping working environments.
</AdmonitionType>
