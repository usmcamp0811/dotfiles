---
# try also 'default' to start simple
theme: seriph
# random image from a curated Unsplash collection by Anthony
# like them? see https://unsplash.com/collections/94734566/slidev
background: https://cover.sli.dev
# some information about your slides, markdown enabled
title: Welcome to Slidev
info: |
  ## Slidev Starter Template
  Presentation slides for developers.

  Learn more at [Sli.dev](https://sli.dev)
# apply any unocss classes to the current slide
class: text-center
# https://sli.dev/custom/highlighters.html
highlighter: shiki
# https://sli.dev/guide/drawing
drawings:
  persist: false
# slide transition: https://sli.dev/guide/animations#slide-transitions
transition: slide-left
# enable MDC Syntax: https://sli.dev/guide/syntax#mdc-syntax
mdc: true
---

# Welcome to Slidev

Presentation slides for developers

<div class="pt-12">
  <span @click="$slidev.nav.next" class="px-2 py-1 rounded cursor-pointer" hover="bg-white bg-opacity-10">
    Press Space for next page <carbon:arrow-right class="inline"/>
  </span>
</div>

<div class="abs-br m-6 flex gap-2">
  <button @click="$slidev.nav.openInEditor()" title="Open in Editor" class="text-xl slidev-icon-btn opacity-50 !border-none !hover:text-white">
    <carbon:edit />
  </button>
  <a href="https://github.com/slidevjs/slidev" target="_blank" alt="GitHub" title="Open in GitHub"
    class="text-xl slidev-icon-btn opacity-50 !border-none !hover:text-white">
    <carbon-logo-github />
  </a>
</div>

<!--
The last comment block of each slide will be treated as slide notes. It will be visible and editable in Presenter Mode along with the slide. [Read more in the docs](https://sli.dev/guide/syntax.html#notes)
-->

---
transition: fade-out
---

# What is Slidev?

Slidev is a slides maker and presenter designed for developers, consist of the following features

- 📝 **Text-based** - focus on the content with Markdown, and then style them later
- 🎨 **Themable** - theme can be shared and used with npm packages
- 🧑‍💻 **Developer Friendly** - code highlighting, live coding with autocompletion
- 🤹 **Interactive** - embedding Vue components to enhance your expressions
- 🎥 **Recording** - built-in recording and camera view
- 📤 **Portable** - export into PDF, PNGs, or even a hostable SPA
- 🛠 **Hackable** - anything possible on a webpage

<br>
<br>

Read more about [Why Slidev?](https://sli.dev/guide/why)

<!--
You can have `style` tag in markdown to override the style for the current page.
Learn more: https://sli.dev/guide/syntax#embedded-styles
-->

<style>
h1 {
  background-color: #2B90B6;
  background-image: linear-gradient(45deg, #4EC5D4 10%, #146b8c 20%);
  background-size: 100%;
  -webkit-background-clip: text;
  -moz-background-clip: text;
  -webkit-text-fill-color: transparent;
  -moz-text-fill-color: transparent;
}
</style>

<!--
Here is another comment.
-->

---
transition: slide-up
level: 2
---

# Navigation

Hover on the bottom-left corner to see the navigation's controls panel, [learn more](https://sli.dev/guide/navigation.html)

## Keyboard Shortcuts

|     |     |
| --- | --- |
| <kbd>right</kbd> / <kbd>space</kbd>| next animation or slide |
| <kbd>left</kbd>  / <kbd>shift</kbd><kbd>space</kbd> | previous animation or slide |
| <kbd>up</kbd> | previous slide |
| <kbd>down</kbd> | next slide |

<!-- https://sli.dev/guide/animations.html#click-animations -->
<img
  v-click
  class="absolute -bottom-9 -left-7 w-80 opacity-50"
  src="https://sli.dev/assets/arrow-bottom-left.svg"
  alt=""
/>
<p v-after class="absolute bottom-23 left-45 opacity-30 transform -rotate-10">Here!</p>

---
layout: two-cols
layoutClass: gap-16
---

# Table of contents

You can use the `Toc` component to generate a table of contents for your slides:

```html
<Toc minDepth="1" maxDepth="1"></Toc>
```

The title will be inferred from your slide content, or you can override it with `title` and `level` in your frontmatter.

::right::

<Toc v-click minDepth="1" maxDepth="2"></Toc>

---
transition: fade-out
image: https://cover.sli.dev
---


# Business Risks with the Standard

    - Reduced productivity from resolving environment issues
    - Higher costs linked to prolonged development and deployment timelines
    - Risk of deploying substandard or vulnerable software
    - Brand image risks from continuous downtime or performance hiccups
    - Exposure to legal issues from non-compliant security practices
    - Slower feature releases leading to competitive lag
    - Revenue impacts from customer turnover or dissatisfaction with service stability

---
transition: fade-out
---


# Immutable Infrastructure with Nix

   - Guarantees uniformity across development, testing, and live environments
   - Diminishes local setup discrepancies, enhancing team efficiency
   - Deployment made straightforward with prescriptive configuration management
   - Quickens developer integration by automating initial setup tasks
   - Provides a reliable mechanism for reverting unsuccessful deployments
   - Secures systems uniformly across the board
   - Promotes infrastructure codification, elevating both efficiency and dependability

---
transition: fade-out
---


# Nix: Under the Hood - Key Concepts and Architecture

   - Isolation in package building through a functional approach
   - Configurations are prescriptive for exact system setups
   - Central package repository housing all versions
   - User-specific setup management allowing seamless transitions and reverts
   - Package building instructions via Nix expressions
   - Ensures all dependencies are declared, avoiding unseen ones
   - Cleans out unneeded packages, optimizing storage
   - Accelerates setup and deployment with ready-made packages

---
transition: fade-out
---


# Case Studies: Success Stories with Immutable Infrastructure

   - **Tech Startup Cuts Deployment Time**: Moved from lengthy deployments to swift, enabling quicker product enhancements.
   - **E-commerce Giant Achieves Near-Perfect Uptime**: Eliminated environmental discrepancies, maintaining high service levels during critical sales periods.
   - **Finance Firm Secures Its Services**: Efficient patch application across extensive networks, meeting high compliance standards effortlessly.
   - **Development Firm Streamlines Developer Onboarding**: Achieved immediate productivity from new hires through consistent setup processes.
   - **Academic Institution Simplifies IT Operations**: Managed software updates with ease across extensive lab setups.

---
transition: fade-out
---

# Implementing Nix in Your Workflow: Practical Steps

   - **Infrastructure Evaluation**: Identify existing bottlenecks and readiness for Nix integration.
   - **Pilot Project Initiation**: Begin with a low-stakes project to test Nix's impact.
   - **Team Education**: Facilitate learning around Nix's principles and operation.
   - **CI/CD Integration**: Modify build and deployment flows to incorporate Nix, utilizing its reproducibility.
   - **Engage with Nix Community**: Tap into the Nix ecosystem for tools and support.
   - **Gradual Nix Expansion**: Extend Nix use as familiarity and confidence grow.
   - **Continuous Review and Adjustment**: Regularly assess and refine your Nix setup.
   - **Community Participation**: Share your journey and contribute to Nix's evolution.

---
transition: fade-out
---

# Overcoming Challenges and Limitations of Nix Adoption

   - **Navigating the Learning Curve**: Introduce thorough training and support for newcomers.
   - **Blending with Legacy Systems**: Plan a gradual integration path to avoid disruption.
   - **Leveraging Community Insight**: Engage with and contribute to Nix's knowledge base.
   - **Addressing Performance Overheads**: Fine-tune Nix configurations for optimal operation.
   - **Ensuring Tool Compatibility**: Adjust existing tools and practices to fit Nix environments.
   - **Cultural Adaptation to New Tools**: Cultivate an openness to technological shifts for smoother adaptation.
   - **Scaling Nix Use Organization-Wide**: Apply best practices for extending Nix's benefits across more teams.
   - **Keeping Skills Current**: Stay informed on Nix advancements to continually enhance your infrastructure.
