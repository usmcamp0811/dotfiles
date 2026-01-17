---
layout: top-title-two-cols
color: dark
columns: is-5
class: text-sm
---

:: title ::

# Built-in Traceability

:: left ::

```mermaid
graph TD
    A[Nix Expression<br><code>default.nix</code><br>Declares package and dependencies] -->|nix-instantiate| B[Derivation<br><code>/nix/store/abc...-hello.drv</code><br>Encodes inputs and build instructions]
    B -->|nix-store --realise| C[Build Process<br>Isolated environment<br>Uses only declared inputs]
    C --> D[Nix Store<br><code>/nix/store/xyz...-hello-2.12.1</code><br>Immutable output with hashed path]
    D -->|nix-store --query --deriver| E[Trace Back to Derivation<br>Retrieve <code>.drv</code> file]
    E -->|nix show-derivation| F[View Inputs<br>List dependencies and sources]
    D -->|nix-store --query --references| G[Trace Dependencies<br>List dependent store paths]
    D -->|nix-store --query --tree| H[Visualize Dependency Tree<br>Full dependency graph]
    style A fill:#f9f9f9,stroke:#333,stroke-width:2px
    style B fill:#e0f7fa,stroke:#333,stroke-width:2px
    style C fill:#bbdefb,stroke:#333,stroke-width:2px
    style D fill:#c8e6c9,stroke:#333,stroke-width:2px
    style E fill:#fff9c4,stroke:#333,stroke-width:2px
    style F fill:#fff9c4,stroke:#333,stroke-width:2px
    style G fill:#fff9c4,stroke:#333,stroke-width:2px
    style H fill:#fff9c4,stroke:#333,stroke-width:2px
```

:: right ::

<div style="margin-top: 1rem; font-size: 0.85rem; line-height: 1.4;">

- **Start with a Nix expression** — declares everything needed to build
- **Instantiated into a derivation (`.drv`)** — captures the full build recipe
- **Build runs in a pure sandbox** — only declared inputs are allowed
- **Produces a hashed output in `/nix/store`** — content-addressed and immutable
- **Reverse traceable** — map output back to its `.drv` and declared inputs
- **Inspect the full dependency graph** — see all runtime and build-time dependencies
- **Transparent by default** — every artifact has a clear and auditable history

</div>

<Admonition title="Strategic Advantage" color="amber-light">
Every step — from source to binary — is reproducible, inspectable, and secure by default.
</Admonition>
