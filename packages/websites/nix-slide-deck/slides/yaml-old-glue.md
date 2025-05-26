---
layout: top-title-two-cols
color: dark
columns: is-3
class: text-sm
---

:: title ::

# YAML: The Old Glue

:: default ::

<AdmonitionType type="important">
<p class="m-0 leading-tight">

_"DevSecOps isn’t just about CI/CD — it’s about trust, traceability, and reproducibility."_

</p>
</AdmonitionType>

:: left ::

<img src="/assets/frankenyaml.png" class="rounded shadow-lg"/>

:: right ::

- YAML handles basic config well, but falls apart under complexity — logic turns into an unreadable mess, as anyone who's wrangled Helm templates knows.
- YAML can describe what you need, but not how to guarantee it — there's no way to enforce that a file is correct, reproducible, or even exists without relying on fragile glue scripts.
- Leads to brittle pipelines (YAML → bash → Docker → CI → ??)
- Creates a disconnect between local development and CI/CD — what works on a dev machine may not reflect what actually gets built or tested.

<!--
- YAML defined pipelines, that have nested scripts that create more YAML. 

- Trying to figure out your SBOM after the fact is tedious and error prone
-->
