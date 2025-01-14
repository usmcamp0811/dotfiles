---
author: Matt Camp
title: 'Nix in the Wild: Taming Terraform with Nix: A Modular Approach'
date: 2025-01-20
image: taming-terraform-nix-sm.png
description: 'Explore how to simplify and modularize your Terraform configurations using Terranix and Nix Flakes. This post covers essential functions, directory structures, and practical examples to streamline your Infrastructure as Code workflow.'
slug: taming-terraform-with-nix-a-modular-approach
tags:
  - Nix
  - Terraform
  - Terranix
  - Infrastructure as Code
  - DevOps
  - Reproducible Builds
  - Cloud
  - AWS
  - Modular Design
  - Software Development
categories:
  - Nix
  - DevOps
  - Infrastructure as Code
  - Cloud Computing
  - Software Engineering

series:
  - Nix in the Wild
---

### **General Outline for the Blog Post**

#### **Introduction**

Welcome back to my ongoing series, _Nix in the Wild_, where I delve into the practical applications of
Nix within organizational contexts, using the fictional company Initech as a narrative framework. In
this installment, I will explore the integration of Terraform into Snowfall-lib-based Nix flakes, offering
a comprehensive guide to adopting this approach in your own workflows. By using the
[Terranix](https://terranix.org/) library together with custom functions I’ve written, this post showcases how these tools
integrate seamlessly with the [Snowfall library](https://snowfall.org/guides/lib/quickstart/), creating
a cohesive and efficient workflow.

Before proceeding, I must acknowledge that I do not position myself as a Terraform expert. I have historically
had reservations about "the cloud" which are rooted in its tendency to incur high costs and my preference
for the hands-on experience of learning and experimenting on personal hardware, which often offers a
more straightforward and transparent approach to problem-solving. Nevertheless, the utility of cloud
infrastructure in certain scenarios cannot be dismissed, and it is imperative to equip ourselves with
tools that enable efficient and secure interaction with such environments.

This post will introduce Terranix, a library that simplifies Terraform configuration management by enabling
developers to write less code while improving reusability. I will demonstrate how I’ve integrated Terranix
modules into the modular structure provided by the Snowfall library, making it easier to organize and
manage infrastructure as code. By defining resources such as Lambda functions or EC2 images directly
within Nix configurations, we can seamlessly integrate these definitions into Terraform workflows, bridging
the gap between declarative configuration and practical cloud resource management.

The discussion will also cover the custom functions I developed to adapt Terranix to the Snowfall library’s
conventions. These functions simplify workflows, ensure better compatibility with existing tools,
and make ongoing maintenance more straightforward. Additionally, I will demonstrate how to incorporate
modules from external flakes, providing a scalable and efficient method for sharing and reusing infrastructure
components across various projects.

The primary advantage of employing Nix in conjunction with Terraform lies in its capacity to significantly
reduce the volume of code required while simultaneously enhancing reusability. By modularizing configurations
and embracing Nix’s declarative paradigm, Terraform can be transformed into a streamlined and maintainable
component of your infrastructure management strategy. This integration not only minimizes complexity
but also fosters a more robust and scalable approach to infrastructure as code. Let us embark on this
exploration together.

#### **What is Terranix?**

My discovery of Terranix began when I started a new project requiring deeper engagement with cloud infrastructure.
Up to that point, my experience with Terraform was limited to minor adjustments in existing projects,
where I often felt constrained by its repetitive and fragmented nature. Even in what I’d consider a
well-organized Terraform project—complete with proper modules—making a seemingly simple change often
required navigating through multiple layers, declaring variables in several places, and painstakingly
ensuring consistency. Additionally, running Terraform required working within the correct directory structure,
adding yet another layer of friction.

When it came to starting a new project, the lack of straightforward mechanisms to reuse modules across
projects without resorting to copy-pasting was frustrating. It’s entirely possible that my limited experience
contributed to these frustrations, but the rigidity and verbosity of Terraform always left me searching
for a better approach. Determined to find a solution that addressed these pain points, I began investigating
alternatives.

Of course, my fondness for Nix naturally influenced my search, leading me to discover Terranix. Initially,
I was skeptical, questioning whether this was merely an exercise in rewriting Terraform within Nix
for its own sake, or whether there was genuine value to be gained. While I’m an advocate for Nix, I also
prioritize practicality—the solutions I build must remain accessible to others who may not share my enthusiasm
for Nix.

After exploring examples on [GitHub](https://github.com/search?q=terranix+language%3ANix&type=repositories&l=Nix) and finding limited resources, my skepticism remained. Nonetheless, I decided to dedicate a weekend
to experimenting with Terranix and exploring its potential to streamline my workflow. What I discovered
not only addressed my initial concerns but also opened new possibilities for simplifying and enhancing
Terraform projects. Let’s dive into what makes Terranix such a compelling tool.



#### **Why Use Terranix with Nix Flakes?**

- Advantages of combining Terranix with Nix Flakes.
- Key features of the Snowfall approach for modular organization.

#### **Setting Up Your Flake for Terranix**

1. Overview of prerequisites (e.g., Nix, Terranix, Terraform).
2. Example `flake.nix` snippet showing how to include Terranix.
3. Explanation of directory structure for Terraform modules.

#### **Key Functions for Terranix Integration**

- Detailed walkthrough of each function:
  1. **`findDefaultNixFiles`**: What it does and usage example.
  2. **`terranixConfiguration`**: Simplifying configuration management.
  3. **`mkTerranixDerivation`**: Generating and managing Terraform configurations.
- Include practical examples for each function.

#### **Building and Organizing Terraform Modules**

- Demonstrate how to create a basic Terraform module (`default.nix` example).
- Best practices for organizing modules in `./modules/terraform`.

#### **Applying and Managing Terraform Configurations**

- Step-by-step guide to running the following commands:
  1. Generating JSON (`nix run .#aws-infrastructure`).
  2. Applying configurations (`nix run .#aws-infrastructure.apply`).
  3. Destroying resources (`nix run .#aws-infrastructure.destroy`).

#### **Example: Managing AWS Infrastructure**

- Walk through the example module (`example.nix`).
- Show how to use the configuration to create S3 buckets and Lambda functions.
- Discuss additional customization options.

#### **Best Practices**

- Tips for keeping your Terraform configurations maintainable and modular.
- Using `extraArgs` and `modules` effectively.
- Testing configurations before applying.

#### **Conclusion**

- Recap the benefits of using Terranix with Nix Flakes.
- Encourage readers to explore the possibilities with their own projects.
- Link to the official Terranix documentation for further reading.

#### **Call to Action**

- Invite readers to try out the example code.
- Suggest sharing their experiences or questions in the comments or via social media.
