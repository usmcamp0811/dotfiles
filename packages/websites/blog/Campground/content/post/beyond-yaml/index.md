+++
author = "Matt Camp"
title = "Beyond YAML: The Case for Nix as the Common Language of DevSecOps"
date = "2025-05-20"
image = "beyondYaml.png"
description = "YAML can't meet the demands of modern DevSecOps. This post makes the case for Nix as the new standard: a secure, declarative, and reproducible foundation for policy enforcement, artifact traceability, and audit-ready builds. Learn why the future of DevSecOps must be functional, not fragile."
tags = [
    "Nix",
    "Flakes",
    "DevSecOps"
]
categories = [
    "Nix",
    "DevOps",
]
+++

# Beyond YAML: The Case for Nix as the Common Language of DevSecOps

YAML has long been the “glue” of DevOps – from CI/CD pipeline configs to Kubernetes manifests. It earned
its place by being simple and human-readable. But today’s DevSecOps reality exposes YAML’s limitations.
Modern software delivery demands more than static config files; it requires enforceable security policies,
verifiable builds, and guaranteed reproducibility at every step. In this post, we’ll explore why YAML,
despite its ubiquity, is no longer sufficient for DevSecOps and why Nix, a purely functional, declarative
build language, is emerging as the smarter foundation for secure, auditable software delivery.

## DevSecOps Has Outgrown Basic YAML Configs

Traditional DevOps focused on speed and automation, often satisfied by YAML-driven pipelines and scripts.
DevSecOps, however, raises the bar by baking security and compliance into the process from the start.
In 2025 and beyond, **DevSecOps pipelines must achieve goals that go far beyond what vanilla YAML can express**:

- **Policy Enforcement at Build Time:** Security checks and compliance rules should trigger during the
  build, not after deployment. For example, secrets should never enter a build, and dependency licenses
  or vulnerabilities should be vetted early. This level of _shift-left_ security demands logic and controls
  in the pipeline that YAML alone can’t dictate.

- **Full Artifact Traceability:** Every artifact (container image, binary, etc.) needs a _provenance_.
  Teams should be able to prove exactly which source code, dependencies, and build process produced a
  given artifact, a response to supply chain threats. Regulators worldwide now demand this proof of integrity,
  and it’s _not optional_ for critical systems.

- **Isolated & Reproducible Builds:** DevSecOps assumes that a build run today can be reproduced exactly
  tomorrow or a year from now, byte-for-byte identical outputs from identical inputs. This requires hermetic,
  isolated build environments where network access and implicit dependencies are controlled. In practice,
  that means no “works on my machine” surprises and no drifting configurations between dev and CI.

- **Continuous Auditability:** Audit logs and build materials (SBOMs, source archives) should be automatically
  produced. If a security incident arises, one should rapidly trace what went into the software and rebuild it
  in a clean room for verification. DevSecOps makes auditability a first-class citizen of the delivery process.

These needs highlight a fundamental truth: **simple configuration files aren’t enough**. YAML was designed
as a data serialization format, not a programming language. As a result, trying to meet DevSecOps requirements
with YAML leads to brittle solutions. Let’s examine why.

## Why YAML Falls Short in a DevSecOps World

YAML’s popularity in DevOps stems from its simplicity, but that simplicity comes with severe trade-offs
when facing security and compliance demands. **YAML lacks the expressiveness and rigor needed for today’s
software supply chains.** It cannot implement dynamic logic or enforce complex policies by itself,
it’s just static data. As one developer bluntly put it, [_"it’s not possible to have the power of Nix/NixOS
with a data language like YAML. It has to be a programming language."_](https://discourse.nixos.org/t/why-not-use-yaml-for-configuration-and-package-declaration/1333/11) In other words, YAML alone
can’t model the sophisticated build rules and verifications that DevSecOps requires.

This limitation has led to an ironic phenomenon: we keep trying to bend YAML into a pseudo-programming
language, with templating hacks, embedded scripts, and vendor-specific DSLs layered on top. CI/CD systems
allow YAML pipelines to call shell scripts and third-party actions, but that just offloads complexity
elsewhere. You end up chaining Dockerfiles, shell scripts, Helm chart YAMLs, and glue logic in CI. This is a
fragile assembly of parts that’s hard to comprehend and even harder to secure. YAML offers no **composability**
or abstraction: you can’t easily reuse pipeline components or compose configurations without copy-pasting
and manual tweaks. This brittleness undermines both **consistency** and **security**. A missed step in
one script or a subtle difference between environments can introduce vulnerabilities or deployment errors
that YAML alone wouldn’t catch.

Most critically, YAML provides no guarantees about **correctness or reproducibility**. Two developers
might follow the same YAML-defined process and get different results if their environments differ or
if external dependencies shift. Nothing in a plain YAML file ensures that, say, the same base image or
package version is used every time – that assurance has to come from external tooling. In short, YAML
can describe _what_ to run, but not _how to guarantee_ it’s done securely and identically each time.
For DevSecOps, that’s not good enough.

## Nix: A Functional, Declarative Solution for Secure Builds

If YAML is a static checklist, **Nix is a blueprint and a engine combined**, a way to _declare_ your
entire build and deployment process with the power of a full programming language. Nix is often described
as a _purely functional package manager_, but it is better thought of as a **build language** and ecosystem
that brings predictability and rigor to software delivery. Each Nix build is treated like a mathematical
function: given the same inputs, it will always produce the same output, with no hidden side effects.
This approach lays a foundation of determinism that is a dream for DevSecOps engineers concerned with
tamper-proof builds.

What makes Nix so suited as the common language of DevSecOps? Let’s break down its key characteristics:

- **Purely Functional and Declarative:** In Nix, you describe the desired state (packages, configuration,
  dependencies) rather than writing step-by-step imperative scripts. The Nix expression language is purely
  functional and even Turing-complete, meaning it can represent any build logic needed. Unlike YAML, you
  can use functions, conditionals, and abstractions to create reusable, composable build definitions. The
  result is that even complex pipelines can be expressed in a single coherent framework, without ad-hoc
  scripting in multiple languages.

- **Isolated, Reproducible Builds by Design:** Nix builds occur in isolated sandboxes with only the declared
  inputs available. External network access or undeclared dependencies are blocked unless explicitly allowed.
  This enforces a "nothing up my sleeve" policy. If it wasn’t declared, it doesn’t get into the build.
  The same Nix build on any machine (developer laptop, CI server, or production) yields identical results
  because Nix will fetch the exact versions of dependencies specified and build in a controlled environment.
  This eliminates the "worked on my machine" problem and ensures consistency between local builds and
  CI.

- **Complete Traceability and Auditability:** Every artifact built with Nix has a traceable lineage.
  Nix keeps track of all dependencies (down to specific versions and even the tools used to compile those
  dependencies). This makes generating a Software Bill of Materials (SBOM) straightforward. The build
  itself knows everything that went into it. Need to audit or comply with regulations? Nix can export the
  exact source code and dependencies that produced a given binary, providing a verifiable chain of custody
  for software. Such transparency is near-impossible to achieve with manual YAML pipelines spread across
  tools.

- **Expressiveness with Safety:** Because Nix is a real language, it allows powerful composition of components
  (for example, you can build a library and an application together, sharing only the exact dependencies
  needed). Yet it remains declarative, meaning you describe end states, and Nix ensures the process respects
  that description. Its strong typing of data types (strings, lists, sets, etc.) and evaluations can catch
  errors early – you can’t accidentally reference an undefined variable or mis-order steps as easily as
  in a free-form script. The Nix ecosystem also provides tested functions and modules (for building common
  languages or frameworks), so you’re not writing everything from scratch. In sum, Nix offers the flexibility
  of a programming language with guardrails for reproducibility and consistency.

## Reproducibility, Traceability, and Policy Enforcement by Default

A fundamental advantage of adopting Nix is how it makes secure practices the default, not an afterthought.
**Reproducibility comes out-of-the-box.** Every Nix build is identified by a cryptographic hash of
its inputs. If anything in the inputs changes (source code, a compiler version, a dependency), Nix will
treat it as a different build output. If nothing changes, Nix can even reuse previous build results bit-for-bit.
This means that whether a developer builds locally or a CI pipeline builds on a fresh machine, Nix
will produce the same binaries, configurations, and images. Consistency is guaranteed, dramatically reducing
"it works in staging but not in prod" headaches.

Because Nix requires declaring all inputs, it inherently supports **policy enforcement** and security
checks at build time. Want to ensure no disallowed software makes it into the product? You can globally
define allowed sources or versions, and Nix won’t import anything outside those whitelists. Builds can
be configured to run in _fully sandboxed mode_ (no network, no impurity), so if a step tries to fetch
an undeclared URL or access a secret, it will fail! Exactly what you want for a secure supply chain.
This shifts security left into the build process, where issues can be caught early. In fact, organizations
concerned with compliance can use Nix to _prove_ that a build had no outside interference: it’s either
reproducible from known inputs or it doesn’t build at all.

Moreover, **traceability is deeply integrated**. With a traditional CI pipeline, assembling an SBOM or
audit trail is a painstaking process of aggregating data from Dockerfiles, package managers, and manual
records. With Nix, the SBOM essentially falls out of the build. For example, one can query the Nix build
graph to get a list of every dependency and produce a formatted SBOM (e.g. CycloneDX or SPDX) in one
command. Nix can even bundle the source code of every dependency into an archive for future audits or
for compliance with regulations that require proving source integrity. This level of detail gives DevSecOps
teams and compliance officers high confidence in the artifacts. As a result, **auditability is continuous**,
every build is ready for inspection without extra work.

## One Coherent Pipeline Replacing Many Fragile Pieces

Perhaps the most transformative aspect of adopting Nix is the simplification of the delivery **toolchain**.
Many teams today suffer from a patchwork pipeline: a Dockerfile to build an image, bash scripts to
glue steps together, YAML files to configure CI tasks, Helm charts to deploy, and so on. Each piece is
written in a different syntax, with different assumptions, often maintained by different people. It’s
no wonder things break. The more moving parts and translation layers, the more chances for error.

![My CI Pipline is simple...](charlie-day.gif)

Nix enables you to consolidate these steps into **one coherent, verifiable process**. You can replace
Dockerfiles with Nix-based container image builds (using Nix functions to produce Docker/OCI images).
Instead of imperative shell scripts that install software and set up environments (which can drift over
time), you write declarative Nix expressions for those environments. The difference is stark: a Dockerfile
might pull in a moving target like “ubuntu\:latest” and run arbitrary commands that update packages (
introducing variability), whereas a Nix build will fetch an exact base image or filesystem layer and
exact versions of packages, ensuring the build is _deterministic_. Where a shell script might rely on
whatever version of a tool is in the `PATH`, a Nix script will call a specific, hashed version of that
tool from the Nix store. Everything is explicit and locked down!

By eliminating the ad-hoc glue, **Nix cuts complexity and risk**. There’s no need for a separate config
language for tests, another for packaging, and another for deployment. All can be described in Nix or
orchestrated by Nix-built tools. This also has productivity benefits: developers and operators speak
a common language (Nix) and have a single source of truth for how software is built and run. No more
hunting through CI YAML files to figure out what environment variable might be missing, or why a build
works in one pipeline stage but fails in another. With Nix, if it builds on your machine, it will build
in CI, period. And once built, that same output can be deployed knowing it hasn’t been tweaked or re-packaged
by an opaque CI step. The entire flow from source to production can be verified end-to-end.

The bottom line is a drastic reduction in the "unknown unknowns" that plague multi-tool pipelines. Nix’s
unified approach replaces the brittle chain of tools (Docker, apt, pip, make, bash, CI config) with
a single, reproducible definition. This coherence means fewer surprises and a tighter alignment between
development intentions and production reality. For organizations, it translates to fewer failed deploys,
faster recovery from issues (because rebuilds are reliable), and easier onboarding of new team members
(since there’s one system to learn rather than five).

## Conclusion: Lead the Next Evolution – Adopt Nix for DevSecOps

DevSecOps is about making secure and compliant software delivery as fast and automatic as traditional
DevOps. But as we’ve argued, trying to achieve that with yesterday’s tools (like plain YAML and a mishmash
of scripts) is like trying to secure a modern skyscraper with the blueprint of a wooden shed, it doesn’t
meet the moment. **Nix offers a path forward**. By using a declarative, reproducible, and expressive
approach, Nix fulfills the core needs of DevSecOps in a way YAML never can. It enables policy enforcement,
traceability, isolation, and auditability _from the ground up_, not as bolted-on afterthoughts.

Nix isn’t just about security, it’s about _business resilience and efficiency_.
["What once took months to achieve in terms of reproducibility and version control can now be accomplished in a matter of hours."](https://flox.dev/blog/nix-in-the-wild-pdt-partners/)
Organizations adopting Nix have found they can meet stringent security requirements
**without slowing down development or inflating costs**. Developers get to work with the latest tools
and libraries, while the Nix framework guarantees that the resulting products are consistent and verifiably
secure. Compliance audits that used to take weeks of chasing documentation can turn into an automated
report from a Nix build. And when regulators or customers ask for evidence of your software’s integrity,
Nix provides an answer grounded in math and computer science, a verifiable "proof" of how your software
was constructed.

The momentum behind Nix is growing, with a vibrant community and increasing adoption in industry (its
popularity has been growing _exponentially_ in recent years). [Forward-thinking leaders are already investing
in Nix skills and pilot projects.](https://flox.dev/blog/nix-in-the-wild-pdt-partners/) As an industry, if we embrace Nix as the standard language of DevSecOps,
we move toward a future where **secure, verifiable builds are the default rather than the exception**. Imagine
a world where every build output can be trusted, where supply chain attacks are thwarted
by design, and where development speed doesn’t suffer for security. That’s the future Nix is pointing
us to.

**Call to action:** It’s time to move beyond the comfort of YAML and scripts and into a more robust paradigm.
If you are in a position of leadership encourage your teams to evaluate Nix for your build pipelines and
deployments. Start with a small project, leverage the wealth of Nix resources and community support,
and see the benefits firsthand. Adopting Nix today is an investment in the stability and security of
your software supply chain tomorrow. In an era of ever-increasing cyber threats and compliance pressures,
Nix isn’t just a niche tool, it’s a strategic advantage. Embrace the change, and lead your organization
into a more secure, reproducible, and confident DevSecOps era.
