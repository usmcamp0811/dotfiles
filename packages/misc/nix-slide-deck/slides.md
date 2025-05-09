---
title: "Nix: Taming the Wild West of Codebases"
theme: default
---

---

# Intro

Welcome to a new way of thinking about development environments, infrastructure, and reproducibility.

---

# What is Nix?

Nix is **not** just a package manager or a build tool.

It's a way to **standardize your entire codebase**.

Historically, projects have used:

- Style guides (but nothing enforces structure)
- Chef / Puppet / Ansible (bandaids over traditional package managers)

These tools **do not guarantee state**.

Nix does.

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
