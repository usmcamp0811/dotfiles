---
title: "Nix: Taming the Wild West of Codebases"
markdown-it:
  plugins:
    - markdown-it-container
theme: ./themes/slidev-theme-neversink
lineNumbers: true
---

<style>
.bluf-box {
  @apply text-sm bg-blue-100 text-blue-800 border-l-4 border-blue-500 p-3 my-4 rounded;
}
</style>

---
layout: cover
color: dark
class: text-right
---

# Nix

## Taming the Wild West of Codebases

<div class="text-sm mt-4">
  🐍💻 Reproducible environments, declarative infra, and zero-footgun dev setups  
</div>

<div class="text-xs opacity-50 mt-2">
  Presented by AICampground • 2025
</div>

---
layout: cover
color: dark
---

# What We'll Cover

- 🧱 Why traditional tools fall short
- 🌀 How Nix changes the game
- 📦 Package management with Nix
- 📦 Container builds with Nix
- ☸️ Kubernetes and Terraform with Nix
- 🧠 Abstraction and reuse in infra
- 🧪 Building reliable, testable systems

<div class="bluf-box mt-10">
  <strong>BLUF:</strong> We're going to reimagine how you manage systems, from dev to prod, using Nix.
</div>

---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# What is Nix?

:: default ::

<div class="bluf-box clear-both mt-8">
  <strong>BLUF:</strong> Nix isn’t another tool on sand — it’s the rock-solid foundation your entire software ecosystem.
</div>

:: left ::

<div class="text-sm leading-relaxed">
Most tools build <strong>on top</strong> of mutable, fragile foundations.  
Like building a house on sand, you're always one gust away from breakage.

Nix builds <strong>from the ground up</strong> on a cryptographic, content-addressed store, ensuring:

<ul class="list-disc ml-4 mt-2">
  <li>🪨 <strong>A solid, reproducible base</strong> — Every dependency, build input, and configuration is pinned. Your app builds the same today, tomorrow, and on any machine.</li>
  <li>🔄 <strong>Immutable builds</strong> — No surprises from "latest" or system drift. A build that worked once will always work again, byte-for-byte.</li>
  <li>🧱 <strong>Consistency across environments</strong> — From your laptop to CI to production, Nix ensures identical environments without "it works on my machine" bugs.</li>
</ul>
</div>

:: right ::

<div class="flex justify-center items-end h-full pb-6">
  <img src="/assets/house_on_rock_and_sand.jpg" class="rounded shadow-lg max-w-[300px]" />
</div>

---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# Critical Qualities, Critical Domains

:: default ::

<div class="bluf-box clear-both mt-8">
  <strong>BLUF:</strong> The guarantees Nix gives us—reproducibility, immutability, consistency—are the same qualities demanded in defense, government, and critical infrastructure.
</div>

:: left ::

<div class="text-base leading-relaxed">
In national security, public infrastructure, and regulated industries, failure is not an option.  
We demand:

<ul class="list-disc ml-4 mt-2">
  <li><strong>Predictable deployments</strong> — Systems must behave the same way every time, everywhere.</li>
  <li><strong>Immutable records</strong> — We can't trust logs or binaries that change under us.</li>
  <li><strong>Auditable state</strong> — What ran, where, and how should always be known.</li>
</ul>

Nix provides these qualities **by design**, not as bolt-ons or afterthoughts.

</div>

:: right ::

<div class="flex justify-center items-end h-full pb-6">
  <img src="/assets/mission-critical.jpg" class="rounded shadow-lg max-w-[300px]" />
</div>

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
