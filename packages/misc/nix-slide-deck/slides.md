---
theme: ./themes/slidev-theme-neversink
lineNumbers: true
layout: cover
color: both
class: text-right
neversink_string: "Nix: Taming the Wild West of Codebases"
colorSchema: light
routerMode: hash
title: Nix
---

<style>
.bluf-box {
  @apply text-sm bg-blue-100 text-blue-800 border-l-4 border-blue-500 p-3 my-4 rounded;
}
</style>

# Nix

## Taming the Wild West of Codebases

<div class="text-sm mt-4">
  🐍💻 Reproducible environments, declarative infra, and zero-footgun dev setups  
</div>

<div class="text-xs opacity-50 mt-2">
  Presented by Matt Camp • 2025
</div>

<!--
## 🔷 Slide Deck Outline: *Nix — Taming the Wild West of Codebases*

### I. **Opening: Set the Stage**

1. **Title Slide**

   * Presentation title, subtitle, presenter info
2. **What is Nix, Really?**

   * Clarify confusion: Nix ≠ Nixpkgs ≠ NixOS
   * Show the triangle diagram
   * Define Nix at its core (reliable file generator)


### II. **Motivation: Why Nix Matters**

3. **Rock-Solid Infrastructure Starts Here**

   - Problems with mutable infra
   - Nix’s reproducible store

4. **Critical Qualities, Critical Domains**

   - Tie to high-assurance environments: defense, infra, compliance

5. **Traditional Approaches**

   - Style guides, config management, Docker, README hell
   - StickyNote: onboarding pain and tribal knowledge

6. **Why Current Tools Fail** 

   - Docker and CI patch problems, don’t solve root cause
   - Composing environments is hard
   - Golden images are fragile


### III. **What Nix Solves**

7. **What Nix Brings**

   - Declarative, reproducible, isolated
   - Mention flakes, nixpkgs, language features

8. **Nix for Package Management**

   - mkShell, nix-env, conflict-free installs

9. **Nix for Containers**

   - dockerTools, buildLayeredImage, no Docker daemon

10. **Nix for Kubernetes**

    - Kubenix, generating manifests, templating infra

11. **Nix for Cloud Infra**

    - Terranix, parameterized, testable infra

12. **Nix as a Language** _(new)_

    - Functional, composable, abstraction-focused
    - Why this helps scale teams


### IV. **Architectural & Org Benefits**

13. **The Power of Abstraction**

    - Enabling org-wide patterns (e.g. `enable = true`)

14. **Cross-Team Consistency** _(new)_

    - Same tool for dev, CI, prod
    - Reduces friction between teams

15. **Security, Audit, and Compliance** _(new)_

    - Repro builds, locked inputs, known state
    - Ideal for SBOMs, reproducible research, and regulated environments


### V. **Call to Action**

16. **The Result**

    - Summary of benefits: determinism, parity, testability
    - “Welcome to the future”

17. **Getting Started** _(optional)_

    - Flakes, nixpkgs, devShell, etc.
    - Link to guides/docs/org-specific onboarding

Want help drafting slides for the next section, like the one about how Docker and golden images still fail?
-->

---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# What <i>is</i> Nix, Really?

:: default ::

<div class="bluf-box clear-both mt-8">
  <b>BLUF:</b> Fundamentally, Nix is just a <b>tool for producing files in the right place</b> — reliably, repeatably, and without surprises.
</div>

:: left ::

<div class="text-base leading-relaxed">
People often confuse Nix with tools <b>built</b> using Nix:

<ul class="list-disc ml-4 mt-2">
  <li>🔧 <b>Nix the Tool</b> — a powerful build engine for reproducible environments</li>
  <li>💻 <b>Nix the Language</b> — a DSL for describing packages, infra, and configs</li>
  <li>📦 <b>nixpkgs</b> — a massive package repository written in Nix</li>
  <li>🖥️ <b>NixOS</b> — a Linux distro built <i>entirely</i> with Nix</li>
</ul>

</div>

But <b>Nix ≠ NixOS</b>, <b>Nix ≠ nixpkgs</b>, and <b>Nix ≠ just a language</b>.

:: right ::

<div class="flex justify-center items-end h-full pb-4">
  <img src="/assets/whatisnix.png" class="max-w-[300px]" />
</div>

---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# Rock-Solid Infrastructure Starts Here

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

<div class="flex min-h-[350px] items-center justify-center">
  <img src="/assets/house_on_rock_and_sand.jpg" class="rounded shadow-lg max-w-[250px]" />
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
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

## Traditional Approaches

:: left ::

<div class="text-sm leading-relaxed">
Before Nix, teams used tools like:

<ul class="list-disc ml-4 mt-2">
  <li>✍️ <strong>Style guides</strong> — Suggestions on folder structure and naming, but not enforced or reproducible.</li>
  <li>🛠️ <strong>Chef / Puppet / Ansible</strong> — Automate config, but often require scripting glue and deep tribal knowledge.</li>
  <li>🔧 <strong>Shell scripts and golden images</strong> — Fast to set up, but impossible to maintain at scale.</li>
  <li>🪢 <strong>Follow README(s)</strong> — "Run these 17 commands in order and hope nothing breaks."</li>
</ul>

These tools stack on top of traditional operating systems and their package managers, which:

- Don’t guarantee state
- Depend on mutable files
- Drift over time without notice

</div>

:: right ::

<div class="flex justify-center items-end h-full pb-6">
  <img src="/assets/stack-of-tools.jpg" class="rounded shadow-lg max-w-[300px]" />
</div>

:: default ::

<StickyNote color="amber-light" textAlign="left" width="180px" v-drag="[720,370,180,180,-8]">
<span style="font-family: 'Comic Sans MS', 'Patrick Hand', cursive;">
Hey! You're new here.  
Go find the README.  
Set up your dev env.  
It's... a journey.  
Ping me if you survive. 😅
</span>
</StickyNote>

<!--
This is why we have tools like Docker, we just build everything from a known state and cross our fingers. But even this is flawed because then we are dependent on golden images and its difficult to compose tools in one image with another.
-->

---
layout: top-title
color: dark
align: l
title: The Traditional Approach
---

:: title ::

# How We Usually Do It

:: content ::

Before Nix, most teams relied on **containers** to define and share dev environments:

- Start with a base image (Ubuntu, Alpine, etc.)
- Use shell scripts to install dependencies
- Manually configure the environment
- Add a startup script
- Pray it works the same on every machine

It works... but it’s fragile, inconsistent, and often hard to maintain.

---
layout: side-title
color: dark
align: l
titlewidth: is-4
title: A Traditional Dockerfile
---

:: title ::

# What It Actually Takes

:: content ::

Replicating our environment with Docker involves:

- Picking a base image
- Installing packages manually
- Embedding a custom script
- Setting up a default command

```dockerfile
FROM alpine:latest

# Install system dependencies
RUN apk add --no-cache figlet ruby && \
    gem install lolcat

# Write our custom script
RUN echo -e '#!/bin/sh\nfiglet "Hello!" | lolcat' > /usr/local/bin/demo && \
    chmod +x /usr/local/bin/demo

# Set default command
CMD ["demo"]
```


<AdmonitionType type="caution">
This is a minimal case — real-world Dockerfiles get much more complex.
</AdmonitionType>

<!--
Bu
-->

---
layout: top-title-two-cols
color: dark
columns: is-4
---

:: title ::

## Why Current Tools Still Fail

:: right ::

Even with "modern" tooling, we're still patching over deep structural problems:

- 🐳 <b>Docker</b> — Starts from clean slates, but depends on <b>mutable golden images</b> that silently rot over time.
- ⚙️ <b>CI Pipelines</b> — Automate builds, but rarely guarantee reproducibility. Flaky tests? Mysterious failures? That's drift.
- 📦 <b>Package managers</b> — Resolve dependencies dynamically, not reproducibly.
- 🧩 <b>Glue scripts & custom bootstrapping</b> — Every team invents their own fragile setup.

These tools are <b>reactive</b> — built to manage breakage — not prevent it.

:: left ::

<div class="flex justify-center items-center h-full">
  <img src="/assets/golden-image.png" class="max-h-[85vh] rounded shadow-lg" />
</div>

---
layout: top-title
color: dark
---

:: title ::

# When ‘latest’ Strikes Again

:: default ::

<div class="flex justify-center items-center h-full">
  <img src="/assets/frustrated-developer.gif" class="max-h-[85vh] rounded shadow-lg" />
</div>

---
layout: top-title-two-cols
color: dark
columns: is-4
align: c-lt-lt
---

:: title ::

## What Nix Brings

:: left ::

<div class="flex min-h-[400px] items-center justify-center">
  <img src="/assets/Nix_Snowflake_Logo.svg" class="max-w-[250px]" />
</div>

:: right ::

<div class="text-lg leading-relaxed space-y-5">
  <div>📜 <b>Declarative environments</b> — Say what you want your system to look like, and Nix makes it so.</div>
  <div>♻️ <b>Reproducibility</b> — Builds and environments that work the same across every machine, every time.</div>
  <div>🧰 <b>Unified config</b> — Use one language and toolset to manage everything: packages, containers, infra, and more.</div>
  <div>🧪 <b>Sandboxed builds</b> — Each build runs in a clean room, so nothing sneaks in or breaks unexpectedly.</div>
  <div>🔁 <b>Immutable deployments</b> — Roll back instantly, upgrade safely. Your systems are always in a known state.</div>
</div>

---
layout: top-title
color: dark
align: c
---

:: title ::

# 🧠 Nix as a Language

:: content ::

<div class="text-lg leading-relaxed text-center max-w-3xl mx-auto mt-6">
Nix isn’t just a config format — it's a <b>purely functional language</b> built for reproducibility and reuse.
</div>

<div class="max-w-2xl mx-auto mt-10 space-y-5 text-base leading-relaxed">
  <div class="flex items-start gap-3">
    <div>🧪</div>
    <div><b>Pure functions only depend on their inputs</b> — no hidden state, no side effects. Same inputs always produce the same outputs.</div>
  </div>

  <div class="flex items-start gap-3">
    <div>📦</div>
    <div><b>Your infrastructure becomes predictable code</b> — no drift, no “why is it different this time?” moments.</div>
  </div>

  <div class="flex items-start gap-3">
    <div>🔁</div>
    <div><b>Every build is deterministic</b>, so CI, staging, and production are truly identical — not just “close enough.”</div>
  </div>
</div>

<div class="mt-10 text-sm text-center opacity-60">
Purity isn’t a restriction — it’s what makes reproducibility possible.
</div>

---
layout: side-title
align: rm-lm
titlewidth: is-3
---

# Just a little code...

<div class="subtle">
  Just enough to impress — not stress.
</div>


---
layout: side-title
side: left
titlewidth: is-4
align: rm-lt
title: Code Example
---

:: title ::

A shell to a Container

:: content ::

````md magic-move

```nix
# Make a list of packages we might want in our environment
envPkgs = [pkgs.cowsay pkgs.figlet];
```
```nix
# Create a simple shell script that does something
script = pkgs.writeShellScriptBin "demo" ''
  echo "Nix the Planet!" | cowsay 
'';
```

```nix
# Or you can specify the package in the script
script = pkgs.writeShellScriptBin "demo" ''
  cowsay "Nix the Planet!" | figlet | ${pkgs.lolcat}/bin/lolcat
'';
```
```nix
# Put that script into some environment
env = pkgs.buildEnv {
  name = "flashy-env";
  paths = envPkgs ++ [script];
};
```
```nix
# Use that environment in a DevShell
devShells.${system}.default = pkgs.mkShell {
  packages = [env];
};

# Or make a Docker container with it
packages.${system}.container = pkgs.dockerTools.buildImage {
  name = "flashy-env";
  tag = "latest";
  contents = [env];
  config.Cmd = ["demo"];
};
```

```nix 
{
  description = "Example Flake that uses the same environment in a DevShell as in a Dockt Container";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs, }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    envPkgs = [pkgs.cowsay pkgs.figlet];
    script = pkgs.writeShellScriptBin "demo" ''
      cowsay "Nix the Planet!" | figlet | ${pkgs.lolcat}/bin/lolcat
    '';
    env = pkgs.buildEnv {
      name = "flashy-env";
      paths = envPkgs ++ [script];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [env];
    };
    packages.${system}.container = pkgs.dockerTools.buildImage {
      name = "flashy-env";
      tag = "latest";
      contents = [env];
      config.Cmd = ["demo"];
    };
  };
}
```

````

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

- 🧰 Built a **devshell** with custom packages and our own script  
- ⚡ Activated instantly with a single `nix develop`  
- 🐳 Reused the exact same setup to build a **Docker image**  
- 🔁 One config — consistent across shell and container, no duplication

<AdmonitionType type="tip">
This is the power of declarative, composable tooling. One definition — everywhere.
</AdmonitionType>

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
