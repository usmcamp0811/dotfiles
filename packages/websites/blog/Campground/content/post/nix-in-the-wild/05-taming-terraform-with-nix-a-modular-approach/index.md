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

# What is Terranix?

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

### Addressing Terraform’s Verbosity

One of the most immediate benefits of Terranix is its ability to reduce Terraform's verbosity.
Instead of defining variables in multiple places within Terraform, you can leverage Nix variables directly.
Additionally, Terranix allows you to utilize Nix functions and modules to further streamline and simplify
Terraform configurations, making them more concise and easier to manage.

### Enhancing Reusability

Terranix makes it straightforward to create reusable modules, eliminating the need to copy and paste
code across projects. With Terranix, you can define and share modules as part of your Nix configuration,
enabling better modularity and reducing redundancy across projects.

### Seamless Integration into Nix Workflows

Terranix integrates naturally into Nix-based workflows, aligning with the declarative and reproducible
philosophy of Nix. This integration allows for seamless transitions between managing Nix and Terraform
configurations, providing a unified approach to infrastructure management.

## How to Use Terranix

Reading through the Terranix [documentation](https://terranix.org/documentation/getting-started.html)
helped me get up to speed with writing basic, non-module configurations quickly. However, I found myself
questioning whether this approach truly offered an improvement over standard Terraform workflows. While
the [documentation](https://terranix.org/documentation/modules.html) emphasized modules as a key feature, the process for effectively utilizing them wasn’t
immediately clear. In this section, I will clarify how to work with modules in Terranix, explaining
it in simpler terms based on my own experiences.

**Update `flake.nix`**

The first thing we need to do is add `"github:terranix/terranix"` to the `inputs` section of our `flake.nix`

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  snowfall-lib = {
    url = "github:snowfallorg/lib";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  devshell.url = "github:numtide/devshell";

  nix-tutor.url = "gitlab:usmcamp0811/nix-tutor";

  poetry2nix.url = "github:nix-community/poetry2nix";

  terranix.url = "github:terranix/terranix"; # <-- We added this right here
};
```

### Create a Terraform Package

The way that we use Terranix is as just another Nix "package". This means that we create a
new folder in the `./packages` directory. I am going to call this `cloud-infrastructure`
you can call it whatever makes the most sense to you. In this folder we add out standard
`default.nix` file and at least one additional Nix file, in this case I am calling it `terranix.nix`.
In this file is going to be your Terranix configuration.

```nix
├──  packages
│   ├──  cloud-infrastructure
│   │   ├──  default.nix
│   │   └──  terranix.nix
```

I am going to show what goes in your `default.nix` and `terranix.nix` files and work backwards
from there explaining why I did certain things.

**`default.nix`**

```nix
{ lib, pkgs, system, ... }:
with lib.initech;
mkTerranixDerivation {
  inherit pkgs system;
  modules = [ ./terranix.nix ];
}
```

What this is, is simply a helper function I created that wraps the Terranix function `terranixConfiguration`
and adds to it a couple of pass through things for creating a state s3 bucket for managing Terraform state,
applying and destroying your Terraform. This is because all the `terranixConfiguration` function really does
for us is convert Nix configurations into Terraform `json`. The main thing that this function takes in as
an argument is a list of Nix files that contain our Terranix configurations.

**`terranix.nix`**

```nix
{ config, pkgs, ... }: {
  config.data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
  config.provider.aws.region = "us-east-1";
  config.backend.s3 = {
    bucket = "initech-state-bucket";
    key = "state/terraform.tfstate";
    region = "us-east-1";
  };
  config.aws = {
    storage = {
      s3 = {
        enable = true;
        defaultIpWhiteList = [ ];
        buckets = { initech-input-bucket = { enable = true; }; };
      };
      ecr = {
        enable = true;
        registeries = [{ name = "my-main-ecr"; }];
      };
    };

    lambda = {
      jobs.another-example-job = {
        lambda-image = pkgs.initech.aws-lambda-image;
        environment.variables = {
          LATITUDE = "38.9072";
          LONGITUDE = "-77.0369";
          S3_BUCKET = "initech-output-bucket";
          S3_KEY = "forecasts/washington_dc_forecast.json";
        };
      };
      pdf-ocr = {
        enable = true;
        variables = {
          INPUT_BUCKET = "initech-input-bucket";
          OUTPUT_BUCKET = "initech-output-bucket";
        };
      };
      weather-job = {
        enable = true;
        variables = {
          LATITUDE = "40.4406"; # Latitude for Pittsburgh, PA
          LONGITUDE = "-79.9959"; # Longitude for Pittsburgh, PA
          S3_BUCKET = "initech-output-bucket";
          S3_KEY = "forecasts/pittsburgh_forecast.json";
        };
      };
    };
  };
}
```

This file introduces more complexity compared to our `default.nix`, but when broken down, it becomes
manageable. The key takeaway here is that this file serves as the central location for defining Terranix
configurations, enabling Terranix modules, or doing both, as demonstrated in this example.

By examining the following Nix snippet, we can begin to understand how Terranix simplifies Terraform workflows:

```nix
config.data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
config.provider.aws.region = "us-east-1";
config.backend.s3 = {
  bucket = "initech-state-bucket";
  key = "state/terraform.tfstate";
  region = "us-east-1";
};
```

If you are familiar with Terraform, the corresponding HCL equivalent may look familiar:

```hcl
data "http" "public_ip" {
  url = "http://checkip.amazonaws.com/"
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "initech-state-bucket"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}
```

This comparison illustrates how Terranix leverages Nix to represent configurations typically written
in Terraform. The advantage lies in Nix's powerful abstraction capabilities, which simplify managing,
sharing, and reusing configurations. The other parts of this file consist of custom modules that I have
created and integrated here; I will discuss these modules in greater detail later.

If you wanted to organize all of your Terranix in this package folder you could and you wouldn't need
my wrapper functions but it might be a little more complex to import them into other Flakes.

### Library Functions Explained

A quick refresher: all library functions for Snowfall-based flakes go in the `./lib` folder. I put the
functions for Terranix in `./lib/terranix/default.nix`.

**`findDefaultNixFiles`**

I created this function to find nested `default.nix` files in a directory structure, similar to how Snowfall
organizes its NixOS modules. While there may already be a Snowfall function for this, I decided to write
my own after a brief search didn’t yield results. This function takes a folder path and returns a list
of paths to all `default.nix` files within it. This is particularly useful for organizing Terraform/Terranix
modules under the `./modules/terraform` folder, mirroring Snowfall’s conventions for `nixos`, `home`,
and `darwin` modules. As I refine my ideas around using Terranix, I may eventually propose incorporating
them into Snowfall proper.

```nix
findDefaultNixFiles = path:
  let
    scanDir = dir:
      let
        entries = builtins.readDir dir;
        files = builtins.filter
          (name:
            let entry = entries.${name};
            in entry == "regular" && builtins.match ".*default\\.nix$" name != null)
          (builtins.attrNames entries);
        filePaths = builtins.map (file: "${dir}/${file}") files;
        subDirs = builtins.filter
          (name: let entry = entries.${name}; in entry == "directory")
          (builtins.attrNames entries);
        subDirPaths = builtins.concatLists
          (builtins.map (subDir: scanDir "${dir}/${subDir}") subDirs);
      in
      filePaths ++ subDirPaths;
  in
  scanDir path;
```

Currently I export the modules discovered with this function as a list of file paths that
can easily be imported into other flakes. I would like to be able load them and have them
indexable like `nixosConfigurations` but I haven't figured out how to correctly do that yet.

```nix
outputs = inputs:
  let
    inherit (inputs) deploy-rs;
    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;
      snowfall = {
        meta = {
          name = "initech";
          title = "Initech Demo Codebase";
        };

        namespace = "initech";
      };
    };
  in lib.mkFlake {
    channels-config = { allowUnfree = true; };

    terranixModule.modules = lib.findDefaultNixFiles ./modules/terraform;
    overlays = with inputs; [
      poetry2nix.overlays.default
      devshell.overlays.default
    ];
  };
```

If you wanted to use modules exported from a flake like this you can use it like this with the vanilla Terranix function:

```
inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [ ./config.nix ] ++ inputs.campground.terranixModule.modules;
      };
```

And you would enable/configure the modules from the `campground` input flake the same way you would as we are about to cover.

**`mkTerranixDerivation`**

As I mentioned earlier this is just a wrapper around the main Terranix function for creating a Terraform configuration.
It also provides the compiled Terraform `json` and passthrus for running Terraform.

```nix
mkTerranixDerivation = { pkgs, system, extraArgs ? { }, modules }:
  let
    terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
      inherit system;
      extraArgs = { inherit lib pkgs; } // extraArgs;
      modules = findDefaultNixFiles ../../modules/terraform ++ modules;
    };

    # Generates the Terraform JSON configuration.
    tf-json = pkgs.writeShellScriptBin "default" ''
      cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
    '';

    # Applies the Terraform configuration.
    apply = pkgs.writeShellScriptBin "apply" ''
      if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
      cp ${terraformConfiguration} config.tf.json \
        && ${pkgs.terraform}/bin/terraform init \
        && ${pkgs.terraform}/bin/terraform apply
    '';

    # Destroys the Terraform-managed resources.
    destroy = pkgs.writeShellScriptBin "destroy" ''
      if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
      cp ${terraformConfiguration} config.tf.json \
        && ${pkgs.terraform}/bin/terraform init \
        && ${pkgs.terraform}/bin/terraform destroy
    '';

    # Creates an S3 bucket for Terraform state storage.
    create-state-bucket = pkgs.writeShellScriptBin "create-state-bucket" ''
      set -euo pipefail

      BUCKET_NAME=''${1:-"campground-state-bucket"}
      AWS_REGION=''${2:-"us-east-1"}

      echo "Creating S3 bucket $BUCKET_NAME in region $AWS_REGION..."

      ${pkgs.awscli}/bin/aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        $(if [ "$AWS_REGION" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=$AWS_REGION"; fi)

      echo "Enabling versioning on the bucket $BUCKET_NAME..."
      ${pkgs.awscli}/bin/aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled

      echo "Setting default encryption on the bucket $BUCKET_NAME..."
      ${pkgs.awscli}/bin/aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
          "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }]
        }'

      echo "Bucket $BUCKET_NAME setup is complete."
    '';
  in tf-json // { inherit apply destroy create-state-bucket; };
```

### **Building and Organizing Terraform Modules**

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
