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
{ mkShell, pkgs, lib, ... }:
mkShell {
  packages = with pkgs; [
    # declare, don't install
    (
      python3.withPackages (ps:
        with ps; [
          numpy pandas requests
        ])
    )
    jdk17_headless nodejs
    git postgresql
    azure-cli
  ];
  shellHook = ''
    echo "🔥 DevShell ready: Python, Java, Node, DBs, Cloud"
  '';
}
```

:: right ::

<div style="margin-top: 2rem; font-size: 0.9rem;">

- **Same result everywhere** — dev, CI, prod
- **No `apt install`**, no “setup” scripts, no drift
- **Forget README treasure hunts** — run `nix develop` and get to work
- **Your devshell _is_ your build environment**
  If it works locally, it works in CI
- **No container juggling** — no volumes, no bind mounts, no mystery state
- **Declare what you need, Nix handles the rest**

</div>

:: default ::

<AdmonitionType title="Productivity Boost">

Stop shipping "how to run this" docs — start shipping working environments.

</AdmonitionType>
