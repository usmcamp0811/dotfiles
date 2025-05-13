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
