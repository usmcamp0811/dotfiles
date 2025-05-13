---
theme: ./themes/slidev-theme-neversink
lineNumbers: true
layout: cover
color: dark
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


#
<h3>
  <img src="/assets/Nix_Snowflake_Logo.svg" alt="Nix Logo" style="width: 40px; height: 40px; display: inline-block; vertical-align: middle;" />
  A Nix Powered DevSecOps Revolution
</h3>

<div class="text-sm mt-4">
   Avoiding the YAML heat death...
</div>

<div class="text-xs opacity-50 mt-2">
  Presented by Matt Camp • 2025
</div>

<img referrerpolicy="no-referrer-when-downgrade" src="https://matomo.aicampground.com/matomo.php?idsite=5&amp;rec=1" style="border:0" alt="" />

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
