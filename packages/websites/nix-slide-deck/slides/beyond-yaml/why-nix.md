---
layout: top-title-two-cols
color: dark
columns: is-6
---

:: title ::

# Why Nix: Reduce Risk, Increase Certainty

:: left ::

<style>
  .table-title {
    text-align: center;
    font-weight: bold;
    font-size: 0.8rem;
    margin-bottom: 0.25rem;
  }
  table {
    font-size: 0.6rem;
    border-collapse: collapse;
    width: 100%;
  }
  th, td {
    border: 1px solid rgb(31 41 55);
    padding: 0.2em 0.4em;
    text-align: left;
  }
  th {
    background-color: rgb(31 41 55);
    color: white;
  }
</style>

<div style="margin-top: 1.5rem;">
  <div class="table-title">DevSecOps Checklist</div>

  <table>
    <thead>
      <tr>
        <th>Category</th>
        <th>YAML</th>
        <th>Nix</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Expressiveness</td>
        <td>❌ Limited</td>
        <td>✅ Full language</td>
      </tr>
      <tr>
        <td>Reproducibility</td>
        <td>❌ Environment drift</td>
        <td>✅ Byte-for-byte reproducible</td>
      </tr>
      <tr>
        <td>Traceability</td>
        <td>❌ Manual logs</td>
        <td>✅ Full artifact lineage</td>
      </tr>
      <tr>
        <td>Security Guarantees</td>
        <td>❌ Trust-based</td>
        <td>✅ Verified inputs + outputs</td>
      </tr>
      <tr>
        <td>Validation</td>
        <td>❌ Manual/error-prone</td>
        <td>✅ Type-checked + pure evaluation</td>
      </tr>
      <tr>
        <td>Composability</td>
        <td>❌ Ad-hoc includes</td>
        <td>✅ Modular imports and abstractions</td>
      </tr>
      <tr>
        <td>Deployment Guarantees</td>
        <td>❌ Drift over time</td>
        <td>✅ Immutable, reproducible deploys</td>
      </tr>
    </tbody>
  </table>
</div>

<div style="margin-top: 3rem;"></div>

:: default ::

<div style="text-align: center; font-size: 0.8rem;">

</div>

<Admonition title="Strategic Insight" color="amber-light" width="260px" v-drag="[120,370,260,120,-8]">

Nix doesn’t just build software—  
it **proves** it was built exactly as intended.

</Admonition>

:: right ::

<div style="font-size: 0.95rem;">

- **Declarative and Verifiable** — expresses system intent as pure functions, enabling transparent, auditable, and predictable infrastructure behavior
- **Eliminates Fragile Glue Code** — replaces ad-hoc scripts with structured, deterministic builds that reduce operational risk and complexity
- **Built-in Trust Boundaries** — ensures integrity with content-addressed storage and isolated, side-effect-free evaluation
- **Provenance and Reproducibility by Design** — delivers CI/CD pipelines with guaranteed artifact integrity, full traceability, and regulatory compliance readiness

</div>
