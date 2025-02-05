# How Nix Works

This diagram provides a high-level overview of how a Nix script is processed. It illustrates the flow
from defining configurations to storing outputs in `/nix/store`.

1. **User defines** a configuration in `config.nix`.
2. **Nix evaluates and compiles** the configuration.
3. **Shell scripts and programs** are generated as needed.
4. **Nix builds and compiles** programs based on the configuration.
5. **Shell scripts execute programs** when run.
6. **All outputs** (configurations, binaries, and scripts) are stored in `/nix/store` for reproducibility
   and caching.

```mermaid

sequenceDiagram
    participant User
    participant Nix
    participant /nix/store
    participant config.nix
    participant ShellScript
    participant Program(s)

    User ->> config.nix: Defines configuration
    Nix ->> config.nix: Evaluates and compiles
    config.nix ->> ShellScript: Generates
    Nix ->> ShellScript: Evaluates and compiles
    Nix ->> Program(s): Builds and compiles
    ShellScript -->> Program(s): Executes
    config.nix -->> /nix/store: Outputs stored
    Program(s) -->> /nix/store: Binaries stored
    ShellScript -->> /nix/store: Scripts stored
```
