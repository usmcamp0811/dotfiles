---
title: "Nix: Taming the Wild West of Codebases"
markdown-it:
  plugins:
    - markdown-it-container

theme: ./themes/theme-bricks
lineNumbers: true
layout: cover
class: text-right
---

<style>
.bluf-box {
  @apply bg-blue-100 text-blue-800 border-l-4 border-blue-500 p-4 my-4 rounded;
}
</style>

---

# Introduction

Welcome to a new way of thinking about development environments, infrastructure, and reproducibility.

---

# What is Nix?

Nix is **not** just a package manager or a build tool.

<div class="bluf-box clear-both mt-8">
  <strong>BLUF:</strong> Nix isn't just a tool — it's a foundation for reproducible systems.
</div>

::left::
It's a **paradigm shift** — a way to **standardize your entire codebase**.

::right::


---

## 🧱 Traditional Approaches

Historically, projects relied on:

- ✍️ Style guides
- 🛠️ Chef / Puppet / Ansible

But these tools...

- Only suggest structure
- Rely on mutable state
- Work **on top of** traditional distros

<!-- image: ./images/stack-of-tools.jpg -->

<div class="bluf-box">
  <strong>BLUF:</strong> Existing tools patch over problems without solving them.
</div>

---

## 🚫 What They Don't Guarantee

- No **guaranteed state**
- No **isolated environments**
- No **atomic upgrades/rollbacks**
- No **determinism across teams or machines**

<!-- image: ./images/frustrated-dev.jpg -->

<div class="bluf-box">
  <strong>BLUF:</strong> Most tools can’t promise your system will stay the same.
</div>

---

## ✅ What Nix Brings

- Declarative, reproducible environments
- Everything from packages to infra in one config
- Consistent behavior across dev, CI, and prod
- Immutable, sandboxed builds

<!-- image: ./images/nix-pipeline.jpg -->

<div class="bluf-box">
  <strong>BLUF:</strong> Nix provides predictable, declarative, and isolated systems.
</div>

---

# Nix for Package Management

- Declaratively install packages
- Isolated, conflict-free environments
- Reproducible builds
- Works the same on every system

Example:

```nix
{ pkgs }: pkgs.mkShell {
  buildInputs = [ pkgs.python3 pkgs.poetry ];
}
```

---

# Nix for Containers

- Build OCI images without Docker daemon
- Use `buildLayeredImage` or `dockerTools`
- Declarative container builds

```nix
pkgs.dockerTools.buildLayeredImage {
  name = "my-app";
  contents = [ pkgs.curl myApp ];
}
```

---

# Nix for Kubernetes

- Manage K8s manifests as Nix code
- Tools like Kubenix, NixJson
- Reusable, parameterized deployments

Example:

```nix
kubenix.modules.kubernetes.deployment {
  name = "web";
  image = "nginx:latest";
  replicas = 2;
}
```

---

# Nix for Cloud Infrastructure

- Define Terraform with Terranix
- Use functions, not static YAML
- Abstract environments into reusable modules

Example:

```nix
{ config, ... }:
{
  aws.lambda = {
    name = "process-data";
    image = myNixBuiltImage;
  };
}
```

---

# Nix is Fundamentally Low-Level

Unlike YAML, Nix:

- Supports functions
- Allows inlined packages
- Is a full programming language

You can:

- Define Terraform modules
- Generate Lambda containers
- Automate entire infra setups

Write once, abstract away complexity, and **test everything at build time**.

---

# The Power of Abstraction

With smart module design:

- `aws.flink-cluster.enable = true` can trigger:
  - IAM setup
  - Networking
  - Monitoring
  - Logging
  - Container builds

You say **what** you want. Nix handles the **how**.

---

# The Result

- Determinism
- Reproducibility
- Dev & Prod parity
- Fewer footguns

Welcome to the future of infrastructure and development environments.

**Welcome to Nix.**
