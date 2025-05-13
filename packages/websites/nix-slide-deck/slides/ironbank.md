
---
layout: top-title-two-cols
columns: is-6
align: l-lt-lt
color: dark
style: |
  .smaller-cols {
    font-size: 0.9rem;
    line-height: 1.4;
  }
---

:: title ::

# Binary Delivery: Cachix vs Iron Bank

:: left ::

<div class="smaller-cols">

## Nix Binary Cache 

- 🌐 Decentralized binary cache as a service  
- ⚙️ Push or pull via `nix copy` or Flakes  
- 🔒 Can be **public or private**  
- 📦 Works seamlessly with **SBOMs** and provenance  
- ⚡ Fast, scalable, supports **signed builds**  
- 🧰 Ideal for developer workflows and CI/CD  
- 🪜 Simple CLI tools and automation support  

</div>

:: right ::

<div class="smaller-cols">

## Iron Bank (DoD / Platform One)

- 🧱 Centralized hardened container registry  
- 🛡️ Strict vetting process with manual review  
- 🔒 Enforces compliance policies (e.g., STIGs)  
- 📄 Requires extensive documentation & justification  
- 🐢 Slower to update, less developer-friendly  
- 🎯 Tailored for mission-critical DoD deployments  
- 🧩 Complex integration into CI/CD pipelines  

</div>

:: default ::

<AdmonitionType type="note">
Both aim to provide trusted binaries — but target very different ecosystems and tradeoffs.
</AdmonitionType>

