---
theme: ./themes/slidev-theme-neversink
lineNumbers: true
color: dark
neversink_string: "Nix: Taming the Wild West of Codebases"
routerMode: hash
title: Nix
src: ./slides/00-intro.md 
---


---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# Nix: A Paradigm Shift, Not Just Better YAML

:: default ::

<div class="bluf-box clear-both mt-4">

  Nix replaces procedural sprawl with declarative clarity — unlocking reproducibility, scalability, and long-term maintainability.

</div>

:: left ::

### **Org-Level Capabilities**

<ul class="text-sm ml-4 mt-2">
  <li><strong>Hyperconverged SDLC</strong> — one definition for prod, dev, VM, Docker, AMI</li>
  <li><strong>Zero trust in artifacts</strong> — build from source with cryptographic guarantees</li>
  <li><strong>Save time</strong> — minimal boilerplate, reusable logic</li>
  <li><strong>Lower cognitive load</strong> — declare <i>what</i>, not <i>how</i></li>
  <li><strong>Reproducible by default</strong> — inputs = outputs, always</li>
  <li><strong>Long-term upside</strong> — like Python, steady growth toward dominance</li>
  <li><strong>Not new — just right</strong> — the correct idea finally maturing</li>
</ul>

:: right ::

<div class="flex min-h-[300px] items-center justify-center">
  <img src="/assets/6-ways-to-improve-your-business-efficiency-banner.jpeg" class="rounded shadow-lg max-w-[250px]" />
</div>




---
layout: top-title-two-cols
color: dark
columns: is-9
---

:: title ::

# Nix: The DevSecOps Revolution

:: default ::

<div class="bluf-box clear-both mt-8">
  <strong>BLUF:</strong> By baking build logic into the graph itself, Nix enables minimal, secure, reproducible software delivery — even in airgapped environments.
</div>

:: left ::

### **A Paradigm Shift**

<ul class="text-sm ml-4 mt-2">
  <li><strong>Not just better YAML</strong> — a higher-order language</li>
  <li><strong>Encodes relationships natively</strong> — no hidden complexity</li>
  <li><strong>Unified logic</strong> — dev, build, infra all in one graph</li>
</ul>

### **DevSecOps Revolution**

<ul class="text-sm ml-4 mt-2">
  <li><strong>Minimal, secure containers</strong> — near Chainguard by default</li>
  <li><strong>Airgap ready</strong> — lazy evaluation, full graph builds offline</li>
  <li><strong>No setup tax</strong> — build environments embedded in Nix itself</li>
  <li><strong>Do more with less</strong> — small teams, large systems</li>
</ul>

:: right ::

<div class="flex items-center justify-center h-full">
  <img src="/assets/devsecops.png" class="rounded shadow-lg max-w-[250px]" />
</div>

---
src: ./slides/01-what-is-nix.md 
layout: top-title-two-cols
color: dark
columns: is-9
---

---
layout: top-title-two-cols
color: dark
columns: is-9
src: ./slides/02-rock-solid.md 
---


---
layout: top-title-two-cols
color: dark
columns: is-9
src: ./slides/03-critical-domains.md 
---


---
layout: top-title-two-cols
color: dark
columns: is-9
src: ./slides/04-traditional-approaches.md 
---

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
align: l-lt-lt
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
  <div><code>&gt;</code> <b>Devshells</b> — Define fully custom CLI environments that can be activated in one step with <code>nix develop</code>.</div>
  <div>♻️ <b>Reproducibility</b> — Builds and environments that work the same across every machine, every time.</div>
  <div>🧰 <b>Unified config</b> — Use one language and toolset to manage everything: packages, containers, infra, and more.</div>
  <div>🔁 <b>Immutable deployments</b> — Roll back instantly, upgrade safely. Your systems are always in a known state.</div>
</div>


---
layout: top-title
color: dark
align: l
---

:: title ::

<h1>
  <img src="/assets/Nix_Snowflake_Logo.svg" alt="Nix Logo" style="width: 40px; height: 40px; display: inline-block; vertical-align: middle;" />
    Nix as a Language
</h1>

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
<span v-mark.underline.orange>Purity isn’t a restriction — it’s what makes reproducibility possible.</span>
</div>

---
layout: side-title
align: rm-lm
color: dark
titlewidth: is-3
---

# Just a little code...

<div class="text-sm opacity-60">

_enough to impress — not stress._

</div>


---
layout: side-title
side: left
titlewidth: is-4
align: rm-lt
color: dark
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

---
layout: top-title
color: dark
align: c
---

:: title ::

# We’re just getting started with what Nix can do.

:: content ::

<div class="flex flex-col items-center justify-center mt-8 space-y-6">
  <img src="/assets/billy-mayes-nix.png" alt="Billy Mays with Nix" class="max-w-[300px] rounded shadow" />
  <p class="text-white text-lg">We’re just getting started with what Nix can do.</p>
</div>


---
layout: top-title-two-cols
color: dark
title: Why Nix Changes the Game
columns: is-10
---

:: title ::

# What If You Could Trust the Files?

:: default ::

<AdmonitionType type="tip">

Declarative systems don’t just build things — they **prove** what they built.

</AdmonitionType>


:: left ::

Nix isn't just a tool — it's a **guarantee**:

- 📁 You know **what every file is**, **where it is**, and **what went into it**
- ✍️ You **declare what you want**, not how to do it
- 📦 Reproducibility isn't an afterthought — it's **baked in**
- 🧬 <span v-mark.underline.orange>Every artifact </span>has a traceable input — you can derive <span v-mark.underline.orange>**SBOMs**, **audits**, and **provenance** by default</span>
- 🏗️ If this is true… you can build *anything* — infra, dev envs, images, whole systems


:: right ::

<div class="flex justify-center items-end h-full pb-4">
  <img src="/assets/trustme.jpg" class="max-w-[300px]" />
</div>

---
layout: top-title
color: dark
align: l
title: From Dev to Delivery
---

:: title ::

# 🧰 From Dev to Delivery: What Nix Unlocks

:: content ::

- 🧪 **DevShells** — Clean, reproducible CLI environments, no setup scripts, no drift  
- 🐳 **Containers** — Same source, same environment, delivered as OCI image  
- 🔧 **Infra as Code, as Functions** — Compose systems with code, not YAML  
- 🔐 **SBOMs by design** — Everything is declared; provenance is automatic  
- 📦 **Binary caching** — Share artifacts securely via Cachix or your own  
- 🔁 **Rollback + consistency** — Immutable builds, reversible deploys

<AdmonitionType type="important">
Nix lets you go from laptop to prod — with trust, traceability, and zero config drift.
</AdmonitionType>

<!--
One definition saves time... 


really good bullets


in the important thing 

important bubble!
-->


---
layout: top-title-two-cols
color: dark
title: SBOM-First Design
---

:: title ::

# SBOM-First by Nature

:: left ::

- 🧬 With Nix, you know exactly **what went into every build** — no guesswork  
- 📦 Every package, patch, and dependency is declared and traceable  
- 🔄 Reproducibility means you can regenerate artifacts — and their SBOMs — anytime  
- 🧾 SBOMs become a **byproduct**, not an afterthought  
- 🔐 Essential for compliance, zero trust, and secure software supply chains

:: default ::

<AdmonitionType type="tip">
In Nix, you don’t bolt on SBOMs — you get them for free.
</AdmonitionType>

:: right ::

<div class="flex justify-center items-end h-full pb-4">
  <img src="/assets/ohmy.webp" class="max-w-[300px]" />
</div>

---
layout: image
image: /assets/nix-wallpaper-nineish-catppuccin-mocha-alt.png
class: text-center
color: dark
---

<div class="text-5xl font-bold tracking-tight mt-10">

From chaos to clarity

</div>

<div class="text-2xl mt-8 leading-relaxed">
  <span class="inline-block mr-4">🔁 Reproducibility</span>
  <span class="inline-block mr-4">📦 Determinism</span>
  <span class="inline-block mr-4">⚖️ Dev ⇄ Prod Parity</span>
  <span class="inline-block mr-4">🧯 Fewer Footguns</span>
</div>

<div class="text-xl mt-10 italic opacity-90">
  The future of infrastructure and development isn't coming —
</div>

<div class="text-xl mt-10 text-accent">
  it's already here. With Nix.
</div>

