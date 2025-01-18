---
author: Matt Camp
title: 'Nix in the Wild: Taming Terraform with Nix: A Modular Approach'
date: 2025-01-21
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

# Taming Terraform with Nix

Welcome back to _Nix in the Wild_, a series exploring real-world applications of Nix within organizations.,
using the fictional company Initech as a narrative framework. In this installment, I will explore the integration
of Terraform into Snowfall-lib-based Nix flakes, offering a comprehensive guide to adopting this approach in
your own workflows. By leveraging the [Terranix](https://terranix.org/) library alongside custom functions
I’ve written, I'll demonstrate how I was able to integrate Terraform seamlessly with the
[Snowfall library](https://snowfall.org/guides/lib/quickstart/) to create a unified,
efficient workflow for managing infrastructure as code.

Before proceeding, I want to share that I am relatively inexperienced with Terraform, so take what I
say on it with a grain of salt. I have historically avoided cloud things due to there potential for high
costs and the simplicity of hacking away on my home lab, but I recognize the necessity to have cloud
capabilities in your toolbox.

I will provide a brief introduction to the NixOS module system for those unfamiliar with it. This will
set the stage to demonstrate how I seamlessly integrated Terranix into the Snowfall structure for organizing
flakes. By defining resources such as Lambda functions or EC2 images directly within Nix configurations,
we can seamlessly integrate these definitions into Terraform workflows, bridging the gap between declarative
configuration and practical cloud resource management.

Using Nix with Terraform introduces an opportunity to simplify cloud infrastructure management while
improving reusability and consistency. By leveraging modular configurations and Nix’s declarative paradigm,
you can create workflows that are both maintainable and scalable. Throughout this post, I will demonstrate
how these tools can work together effectively to streamline your approach to infrastructure as code.

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

### My Terranix Library Functions Explained

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

In this blog series, I haven’t yet covered [NixOS modules in the Snowfall library](https://www.youtube.com/watch?v=ARjAsEJ9WVY&list=PLCNla0W4k0xtpObkpw2xOwWVS24-e3kvL&index=2), but that’s coming soon—consider
this a gentle introduction. Since NixOS and Home Manager modules are stored in the
`./modules` directory, it felt natural to use the same directory for Terraform modules. Given that
Terraform supports multiple providers, I’ve chosen a structure like `./modules/<provider>/...`
to keep things organized and scalable for multi-cloud environments. For the purpose of this post, I’ll
focus on building a couple of AWS modules to illustrate the approach.

### **NixOS Module System Explained**

The NixOS module system is relatively straightforward once you understand one key concept about the Nix
language: **attribute sets can be merged together to create a superset**. This means that if you have
multiple files, each defining an attribute set (e.g., `config`), and you import them all into your `flake.nix`,
Nix will automatically merge them into a single, combined set. Let’s break it down with an example:

---

**File A** defines the following attribute set:

```nix
{
  config = {
    a = "something";
    w = {
      something = "in file A";
    };
  };
}
```

**File B** defines a different attribute set but also includes some overlapping structure:

```nix
{
  config = {
    s = "more stuff";
    w.somethingelse = "in file B";
  };
}
```

When both files are imported into your `flake.nix` or another Nix module, Nix will merge them into a
single `config` attribute set. The result would look like this:

```nix
{
  config = {
    a = "something";
    s = "more stuff";
    w = {
      something = "in file A";
      somethingelse = "in file B";
    };
  };
}
```

Notice how the values are combined—Nix doesn’t overwrite existing values unless explicitly told to. Instead,
it intelligently merges the structure, appending new attributes wherever necessary.

---

This merging behavior is the foundation of the NixOS module system. It allows you to split configuration
across multiple files, keeping things modular and organized. For example, you could have separate files
for system services, user configurations, and application-specific settings, and Nix will seamlessly combine them.

Now that you understand how the module system works, let’s see how we can apply a similar approach to Terraform modules.

---

### **Creating a Basic Terraform Module**

A Terraform module in Nix is essentially a `default.nix` file that defines the configuration for a specific
resource or group of resources. Here’s an example of a basic Terraform module for creating an S3 bucket:

**`default.nix`**

```nix
{ config, pkgs, ... }: {
  config.aws.storage.s3 = {
    enable = true;
    region = "us-east-1";
    buckets = [ "example-bucket" "logs-bucket" ];
    tags = {
      project = "example-project";
      environment = "production";
    };
  };
}
```

This file defines a module for configuring S3 buckets, specifying attributes like the region, bucket
names, and tags. When this module is imported into a larger configuration, it will seamlessly integrate
with other modules using the same merging mechanism explained above.

By organizing your Terraform modules like this, you can reuse and combine them to build more complex
infrastructure configurations while keeping things clean and maintainable.

### **Using Options to Customize Modules**

One of the most powerful features of the NixOS module system is the ability to define **options**. Options
provide a consistent interface for configuring modules, making it easier to customize behavior without
editing the module’s internals. Let’s explore how options work and how to use them effectively in your
Terraform modules.

---

#### **What Are Options?**

Options are configuration parameters enriched with metadata that define how a module behaves. They specify:

- **Name**: The key used to set the value in your configuration.
- **Type**: The expected data type (e.g., string, boolean, list).
- **Default Value**: A fallback value applied if none is explicitly provided.
- **Description**: A brief explanation of the option’s purpose.

By defining options, you provide a clear and consistent interface for users, making modules easier to
configure and integrate into projects.

> **Note:** You can set the `default` value of an option to depend on other parts of your configuration.
> This allows modules to work seamlessly together by default while still enabling customization for scenarios
> that require deviations from the standard setup. Additionally, modules can enable dependent modules automatically,
> ensuring that all necessary dependencies are configured without manual intervention.

---

#### **Defining Options in a Terraform Module**

Here’s an example of how to define options in a Terraform module for managing S3 buckets:

**`default.nix`**

```nix
{ config, lib, ... }: with lib;

{
  options.aws.storage.s3 = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable or disable S3 bucket creation.";
    };

    region = mkOption {
      type = types.str;
      default = "us-east-1";
      description = "The AWS region for the S3 buckets.";
    };

    buckets = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of S3 bucket names to create.";
    };

    tags = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Tags to apply to all S3 buckets.";
    };
  };
}
```

This example defines several options:

- `enable`: A boolean to toggle bucket creation.
- `region`: A string specifying the AWS region.
- `buckets`: A list of bucket names.
- `tags`: A set of key-value pairs for tagging the buckets.

---

#### **Using the Options**

To use these options, create a configuration file in your Terranix package directory and include it in
the `modules` list of your `mkTerranixDerivation` function. Here's an example configuration:

**`./packages/cloud-infrastructure/terranix.nix`**

```nix
{ config, pkgs, ... }: {
  config = {
    data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
    provider.aws.region = "us-east-1";
    backend.s3 = {
      bucket = "initech-state-bucket"; # Use a single bucket for state storage
      key = "state/terraform.tfstate";
      region = "us-east-1";
    };
    aws = {
      storage = {
        s3 = {
          enable = true;
          defaultIpWhiteList = [ ];
          buckets = {
            TPS-reports-bucket = { enable = true; };
          };
        };
      };
      lambda = {
        pdf-ocr = {
          enable = true;
          variables = {
            INPUT_BUCKET = "TPS-reports-bucket";
            OUTPUT_BUCKET = "initech-output-bucket";
          };
        };
      };
    };
  };
}
```

This configuration demonstrates how to customize the module by:

- Enabling S3 bucket creation.
- Specifying `us-east-1` as the AWS region.
- Creating an S3 bucket named `TPS-reports-bucket`.
- Defining Lambda functions with bucket-related environment variables.

> **Note:** If you examine the `./modules/terraform/aws/lambda/pdf-ocr` module, you’ll see that the `initech-output-bucket` is
> created automatically because the `s3` module is invoked within the `pdf-ocr` module.

---

### Deploying Cloud Infrastructure with Terranix

Now that we’ve walked through how to define your infrastructure using Terranix, let’s discuss how to deploy
it. The process involves leveraging passthru attributes provided by the `mkTerranixDerivation` function
to interact with your Terraform configuration.

If you need to manage your Terraform state in an S3 bucket, you can use the `create-state-bucket` passthru.
This passthru simplifies the creation of a bucket to store the state, but you must explicitly reference
the bucket in your Terranix configuration—Terranix does not automatically link it to your Terraform setup.

By default, the derivation outputs the compiled Terraform `json` to `stdout`. This allows you to inspect
the generated configuration before applying it. Once you are ready to deploy, use the `apply` passthru,
which applies the Terraform configuration and provisions the infrastructure. If you need to tear down
the infrastructure, the `destroy` passthru handles the cleanup process.

---

### Understanding Terranix's Nuances

For the most part, translating Terraform configurations into Terranix expressions is straightforward.
However, one area that may initially seem unclear is how to access attributes from Terraform resources
or data sources within Terranix.

This issue is discussed in an [open issue on the Terranix GitHub repository](https://github.com/terranix/terranix/issues/7), as well as in a [pull request](https://github.com/terranix/terranix/pull/59).
While this process is simple, it is not really documented, which can lead to confusion.

To access an attribute, you call it as a function. Here's an example:

```nix
config.data.aws_iam_policy_document.assume_role "json";
```

In this example, the `json` attribute is retrieved from the `aws_iam_policy_document.assume_role` data
source. The syntax makes it easy to extract specific details from a resource, but understanding this
pattern is key to effectively using Terranix.

## Integration with the Nix Ecosystem
