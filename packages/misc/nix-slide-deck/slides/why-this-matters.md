---
layout: top-title
color: dark
align: l
title: Why This Matters
---

:: title ::

# Why This Matters

:: content ::

We defined a full development environment — and then used it two ways:

- Built a **devshell** with custom packages and our own script
- Activated instantly with a single `nix develop`
- Reused the exact same setup to build a **Docker image**
- One config — consistent across shell and container, no duplication
- No volume mounts or host-container sync hacks
- No tribal knowledge — everything's codified
- No guessing which packages are needed to make it build

<AdmonitionType type="tip">
This is the power of declarative, composable tooling. One definition — everywhere.
</AdmonitionType>
