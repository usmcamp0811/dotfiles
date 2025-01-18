---
author: Matt Camp
title: 'Nix in the Wild: Taming Terraform with Nix: A Modular Approach'
date: 2025-01-18
image: terraflake.png
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

Welcome back to _Nix in the Wild_, a series exploring real-world applications of Nix within organizations,
using the fictional company Initech as a narrative framework. In this installment, I will explore the integration
of Terraform into the Initech Snowfall-lib-based flake, offering a comprehensive guide to adopting this approach in
your own workflows. By integrating the [Terranix](https://terranix.org/) library with custom functions, I have established
a foundation for a unified software and infrastructure framework. This framework enables organizations
to seamlessly develop, test, and deploy both applications and the infrastructure they depend on.

Before we dive in, a quick disclaimer: I’m relatively new to Terraform, so take my thoughts on it with
a grain of salt. I’ve mostly avoided cloud-related tools in the past because of the potential for high
costs and the simplicity of working in my home lab. That said, I recognize the importance of having cloud
skills in any business or large organization.

I’ll start with a quick intro to the NixOS module system for anyone who’s not familiar with it. From
there, I’ll show how I integrated Terranix into the Snowfall structure for organizing flakes. By defining
resources like Lambda functions or EC2 images directly in Nix configurations, we can tie these definitions
into Terraform workflows, making it easier to connect declarative configuration with practical cloud
resource management.

Using Nix with Terraform introduces an opportunity to simplify cloud infrastructure management while
improving reusability and consistency. By leveraging modular configurations and Nix’s declarative paradigm,
you can create workflows that are both maintainable and scalable. Throughout this post, I will demonstrate
how these tools can work together effectively to streamline your approach to infrastructure as code.

## What is Terranix?

My discovery of Terranix began when I started a new project requiring deeper engagement with cloud infrastructure.
Up to that point, my experience with Terraform was limited to minor adjustments in existing projects,
where I often felt annoyed by its repetitive and fragmented nature. Even in what I’d consider a
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

After exploring examples on [GitHub](https://github.com/search?q=terranix+language%3ANix&type=repositories&l=Nix) and
finding limited resources, my skepticism remained. Nonetheless, I decided to dedicate a weekend
to experimenting with Terranix and exploring its potential to streamline my workflow. What I discovered
not only addressed my initial concerns but also opened new possibilities for simplifying and enhancing
Terraform projects. Let’s dive into what makes Terranix such a compelling tool.

### Addressing Terraform’s Verbosity

One of the most immediate benefits of Terranix is its ability to reduce Terraform's verbosity.
Instead of defining variables in multiple places within Terraform, you can leverage Nix variables directly.
Additionally, Terranix allows you to utilize Nix functions and modules to further streamline and simplify
Terraform configurations, making them more concise and easier to manage.

### Enhancing Reusability

Terranix simplifies the creation of reusable modules by allowing you to define and share them within
your Nix configuration. This approach promotes modularity and eliminates the need to duplicate code across
projects.

## How to Use Terranix

Reading through the Terranix [documentation](https://terranix.org/documentation/getting-started.html)
helped me get up to speed with writing basic, non-module configurations quickly. However, I found myself
questioning whether this approach truly offered an improvement over standard Terraform workflows.
While the [documentation](https://terranix.org/documentation/modules.html) emphasized modules as a key feature, the process for effectively
utilizing them wasn’t immediately clear. In this section, I will clarify how to work with modules
in Terranix, explaining it in simpler terms based on my own experiences.

### Update `flake.nix`

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

### Create a Terraform Configuration

The way that we use Terranix is as just another Nix "package". This means that we create a
new folder in the `./packages` directory. I am going to call this `cloud-infrastructure`
you can call it whatever makes the most sense to you. In this folder we add our standard
`default.nix` file and at least one additional Nix file, in this case I am calling it `terranix.nix`.

```nix
├──  packages
│   ├──  cloud-infrastructure
│   │   ├──  default.nix
│   │   └──  terranix.nix
```

Here’s what you’ll need to include in your `default.nix` and `terranix.nix` files. I’ll start with these
and then work backward to explain the reasoning behind each step.

**`default.nix`**

```nix
{ lib, pkgs, system, ... }:
with lib.initech;
mkTerranixDerivation {
  inherit pkgs system;
  modules = [ ./terranix.nix ];
}
```

This is a helper function I created to wrap the [`terranixConfiguration` function from Terranix](https://terranix.org/documentation/flakes.html#import-terranix-modules). It adds
a few extras, like passthru support for creating an S3 bucket to manage Terraform state and handling Terraform
apply and destroy actions. The `terranixConfiguration` function itself only converts Nix configurations
into Terraform JSON, so this wrapper streamlines the process. The key argument it takes is a list of
Nix files containing the Terranix configurations.

<p id="terranix-nix"><strong></strong></p>

**`terranix.nix`**

```nix
{ config, pkgs, ... }: {
  config = {
    data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
    provider.aws.region = "us-east-1";
    backend.s3 = {
      bucket = "initech-state-bucket";
      key = "state/terraform.tfstate";
      region = "us-east-1";
    };
    aws = {
      storage = {
        s3 = {
          enable = true;
          buckets = { TPS-reports-bucket = { enable = true; }; };
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

This file is more complex than our `default.nix`, but it’s manageable when broken down. You’re not limited
to just one `terranix.nix` file—you can create multiple files and name them however you like. The content
of this file combines two elements: Terraform converted into Nix syntax and calls to the custom Terranix
modules I’ve created. I will cover modules in a little bit but take a second and see if you can discern
whats happening.

Here’s how Terranix and Terraform compare when defining configurations. The following Nix snippet shows
how Terranix expresses these configurations:

```nix
data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
provider.aws.region = "us-east-1";
backend.s3 = {
  bucket = "initech-state-bucket";
  key = "state/terraform.tfstate";
  region = "us-east-1";
};
```

If you’re familiar with Terraform, the equivalent HCL might look like this:

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

The similarity between the two makes Terranix approachable, even for those who aren’t yet familiar with
Nix. This allows teams with Terraform experience to get started with Terranix more easily while benefiting
from its integration into the Nix ecosystems.

The other part of the `terranix.nix` file above is the declaration and configuration of Terranix modules
for creating S3 buckets and a Lambda function. I’ll dive deeper into Nix modules and how I create them
in the following sections. For now, take a moment to review how we’re calling these modules:

```nix
aws = {
  storage = {
    s3 = {
      enable = true;
      defaultIpWhiteList = [ ];
      buckets = { TPS-reports-bucket = { enable = true; }; };
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
```

This structure showcases how Terranix simplifies and organizes the configuration of cloud resources,
keeping everything declarative and easy to manage.

Finally, I want to clarify that this setup represents just a single Terraform configuration. If our requirements
call for multiple configurations, we can easily add them within the same repo. All we need to do is replicate
the `cloud-infrastructure` folder under a different name. From Nix's perspective, each of these is simply
a Nix package, making it straightforward to manage multiple configurations.

### Deploying our Cloud Infrastructure with Terranix

Now that we’ve walked through how to define your infrastructure using Terranix, let’s discuss how to deploy
it. The process involves leveraging passthru attributes provided by the `mkTerranixDerivation` function
to interact with your Terraform configuration.

```sh
# Display the Terraform JSON configuration
nix run .#cloud-infrastructure

# Equivalent to `tf apply`
nix run .#cloud-infrastructure.apply

# Equivalent to `tf destroy`
nix run .#cloud-infrastructure.destroy
```

If you need to manage your Terraform state in an S3 bucket, you can use the `create-state-bucket` passthru.
This passthru simplifies the creation of a bucket to store the state, but you must explicitly reference
the bucket in your Terranix configuration—Terranix does not automatically link it to your Terraform setup.

---

With this setup, it should be relatively straightforward for non-Nix and non-Terraform users to contribute
to the Nix ecosystem you’re building in your organization. Developers with strong Terraform skills could
create modules that less experienced Terraform users can easily deploy. And this is just the beginning—I
haven’t even touched on how custom Nix packages can seamlessly integrate with the resources we deploy
using Terraform. That’s coming up, but first, let’s dive into the Nix module system.

## Building and Organizing Modules

In this blog series, I haven’t yet covered [NixOS modules in the Snowfall library](https://www.youtube.com/watch?v=ARjAsEJ9WVY&list=PLCNla0W4k0xtpObkpw2xOwWVS24-e3kvL&index=2),
but that’s coming up now—or at least the concepts of modules as they relate to Terranix. NixOS and
Home Manager modules will be covered in a later post.

In the Snowfall structure, NixOS and Home Manager modules are stored in the `./modules` directory, so
it felt natural to use the same directory for Terraform modules. Since Terraform supports multiple providers,
I’ve adopted a structure like `./modules/<provider>/...` to keep things organized and scalable for
multi-cloud environments. For this post, I’ll focus on building a couple of AWS modules to demonstrate
the approach.

![](multi-cloud.png)

### A Brief Explanation of the NixOS Module System

The NixOS module system is relatively straightforward once you understand one key concept about the Nix
language: **attribute sets can be merged together to create a superset**. This means that if you have
multiple files, each defining an attribute set (e.g., `config`), and you import them all into your `flake.nix`,
Nix will automatically merge them into a single, combined set. Let’s break it down with an example:

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

This merging behavior is the foundation of the NixOS module system that Terranix leverages. It allows you to split configuration
across multiple files, keeping things modular and organized. For example, you could have separate files
for system services, user configurations, and application-specific settings, and Nix will seamlessly combine them.

Now that you understand how the module system works, let’s see how we can apply a similar approach to Terraform modules.

### Creating a Basic Terraform Module

A Terraform module in Nix is essentially a `default.nix` file that defines the configuration for a specific
resource or group of resources. Here’s an example of a basic Terraform module for creating S3 buckets:

**`default.nix`**

```nix
{ config, pkgs, ... }: {
  provider.aws = {
    region = "us-east-1";
  };

  resource.aws_s3_bucket.example = {
    bucket = "example-bucket";
    acl = "private";

    tags = {
      Name = "example-bucket";
      Environment = "production";
    };
  };
}
```

This file defines a module for configuring S3 buckets, specifying attributes like the region, bucket
name, and tags. When imported into a larger configuration, this module integrates seamlessly with others,
leveraging Nix's merging mechanism to ensure consistency and flexibility.

By structuring Terraform modules like this, you can easily reuse and combine them to create more complex
infrastructure configurations while keeping everything clean and maintainable. To include these modules
in your `cloud-infrastructure` package discussed earlier, simply add them to the `modules` list.

While this approach is effective, there’s room for improvement. In the next section, I’ll show how we
can refine and enhance this process.

### Using Options to Customize Modules

One drawback of the simple module above is that it doesn't allow customization—every time we use it,
the bucket name would always be `example-bucket`. Wouldn’t it be great if we could parameterize the name?
Well, we can!

One of the most powerful features of the NixOS module system is the ability to define **options**. Options
provide a consistent interface for configuring modules, allowing users to customize behavior without
modifying the module’s internals. This flexibility makes modules reusable and adaptable to different
use cases.

Let’s dive into how options work and how you can use them to make your Terraform modules more customizable
and user-friendly.

#### How do I create Options?

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

#### Defining Options in a Terraform Module

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

#### Using Options to Customize Modules

To use the option, we can refer back to [our example above](#terranix-nix), where we defined an S3 bucket
and a Lambda job. It's important to note that the option path `options.aws.storage.s3` maps to the module
`aws.storage.s3`. While this mapping has no hard relationship to the file’s physical location, maintaining
a folder structure consistent with the module path is helpful for organization and clarity.

This configuration allows us to customize the module by:

- Enabling S3 bucket creation.
- Creating an S3 bucket named `TPS-reports-bucket`.
- Defining Lambda functions with environment variables linked to the S3 buckets.

> **Note:** If you examine the `./modules/terraform/aws/lambda/pdf-ocr` module, you’ll notice that the
> `initech-output-bucket` is automatically created because the `s3` module is invoked within the `pdf-ocr
` module. This modular design keeps related configurations interconnected and manageable.

## Integration with the Nix Ecosystem

Using Nix to generate Terraform configurations makes it easy to integrate components already packaged
with Nix. A great example of this is the Lambda job from [our example above](#terranix-nix).

The Lambda job uses a Python script run from within a container, which is packaged and built by Nix.
This integration combines custom Nix functions with Terraform’s `null_resource` module, allowing Terraform
to execute arbitrary shell scripts during deployment. This tight coupling enables seamless integration
between Nix and Terraform.

### How the Integration Works:

1. **Build the Container Image:** Nix builds the Lambda container image as a `tar` file.
2. **Push to AWS Registry:** A custom script pushes the container to a registry accessible by AWS, set
   up via Terraform.

Here’s an example Nix configuration for the `null_resource` module:

```nix
resource.null_resource = {
  provisioner = {
    local-exec = {
      # ****************************************************************** #
      # This generates the shell script to push the image to the registry. #
      # ****************************************************************** #
      command = "${build-push-lambda-image cfg.job}/bin/build-push ${
        config.resource.aws_ecr_repository."${cfg.job.registry-name}" "repository_url"
      }";
      # ****************************************************************** #
    };
  };
  depends_on = [ "aws_ecr_repository.${cfg.job.registry-name}" ];
  triggers = {
    always_run = true;
    registry_url =
      config.resource.aws_ecr_repository."${cfg.job.registry-name}" "repository_url";
    # ****************************************************************** #
    # This ensures the image is pushed only when its hash changes.        #
    # ****************************************************************** #
    package_hash = lambdaImageTag cfg.job;
  };
};
```

### Key Points:

- **Shell Script Generation:** The `build-push-lambda-image` function generates a script that pushes
  the container to a registry. The `repository_url` is dynamically retrieved from the `aws_ecr_repository`
  attribute defined in Terraform.

- **Efficient Updates:** Using `package_hash`, the container is only pushed when its content changes,
  ensuring efficiency and avoiding unnecessary redeployments.

- **Tightly Integrated Workflow:** Nix builds the container image and Terraform deploys it in a single,
  unified workflow.

This approach streamlines cloud infrastructure deployment. No longer do you need separate steps to build
a container and then deploy it with Terraform—everything is integrated, leading to greater efficiency.

But it doesn’t stop with Lambda jobs. The same logic can apply to:

- **EC2 Deployments:** Create an AMI using Nix flakes, deploy it to AWS, and launch EC2 instances.

- **Long-Running EC2 Instances:** Deploy a NixOS configuration directly to EC2 instances to manage them
  beyond their base image.

With Nix, you can manage your entire cloud infrastructure and application stack from a single configuration,
making integration testing, deployment, and maintenance more efficient and easier to manage.

In future posts, I’ll show how this pattern can be extended to EC2 instances. For now, that’s beyond
the scope of this post, but the possibilities with Nix and Terraform are nearly limitless.

## Understanding Terranix's Nuances

For the most part, translating Terraform configurations into Terranix expressions is straightforward.
However, accessing attributes from Terraform resources or data sources within Terranix can initially
seem unclear.

This issue has been discussed in an [open issue on the Terranix GitHub repository](https://github.com/terranix/terranix/issues/7)
and in a [related pull request](https://github.com/terranix/terranix/pull/59). While the process is relatively
simple, it is not well-documented, which can cause confusion for new users.

To access an attribute, you call it as a function. For example:

```nix
config.data.aws_iam_policy_document.assume_role "json";
```

In this example, the `json` attribute is retrieved from the `aws_iam_policy_document.assume_role` data
source. This syntax makes it easy to extract specific details from a resource, but understanding this
pattern is essential to using Terranix effectively.

### Important Note:

One key discovery is that fetching an attribute like the example above must be done in the **module scope**,
not at the **library function level**. For instance, you cannot create a library function containing
something like:

```nix
config.data.aws_iam_policy_document.assume_role "json";
```

This will fail when called elsewhere. This limitation is why the functions I use in the `null_resource`
are structured as they are, rather than being abstracted into simple wrapper functions. While this
may seem less tidy, it ensures compatibility with how Terranix handles configurations and attributes.

### **Breaking Down My Terranix Library Functions**

This section provides an overview of the custom library functions I created for integrating Terranix
with a Snowfall-based flake. These functions help streamline the process of discovering and using Terraform
modules, generating configurations, and deploying infrastructure.

---

#### **`findDefaultNixFiles`**

This function scans a directory recursively to find all `default.nix` files, making it easier to organize
and discover Terraform/Terranix modules. It’s particularly useful for managing modules under a
`./modules/terraform` structure.

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

This function currently exports the list of file paths, which can be imported into other flakes. While
I’d like to make the modules indexable like `nixosConfigurations`, this functionality remains a work
in progress.

Example usage in the flake output:

```nix
outputs = inputs:
  let
    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;
      snowfall = {
        meta = { name = "initech"; title = "Initech Demo Codebase"; };
        namespace = "initech";
      };
    };
  in lib.mkFlake {
    terranixModule.modules = lib.findDefaultNixFiles ./modules/terraform;
  };
```

---

#### **`mkTerranixDerivation`**

This function wraps the Terranix `terranixConfiguration` function and adds utility scripts for Terraform
tasks such as building JSON configurations, applying changes, destroying resources, and creating S3 state buckets.

```nix
mkTerranixDerivation = { pkgs, system, extraArgs ? { }, modules }:
  let
    terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
      inherit system;
      extraArgs = { inherit lib pkgs; } // extraArgs;
      modules = findDefaultNixFiles ../../modules/terraform ++ modules;
    };

    tf-json = pkgs.writeShellScriptBin "default" ''
      cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
    '';

    apply = pkgs.writeShellScriptBin "apply" ''
      if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
      cp ${terraformConfiguration} config.tf.json \
        && ${pkgs.terraform}/bin/terraform init \
        && ${pkgs.terraform}/bin/terraform apply
    '';

    destroy = pkgs.writeShellScriptBin "destroy" ''
      if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
      cp ${terraformConfiguration} config.tf.json \
        && ${pkgs.terraform}/bin/terraform init \
        && ${pkgs.terraform}/bin/terraform destroy
    '';

    create-state-bucket = pkgs.writeShellScriptBin "create-state-bucket" ''
      BUCKET_NAME=''${1:-"campground-state-bucket"}
      AWS_REGION=''${2:-"us-east-1"}
      echo "Creating S3 bucket $BUCKET_NAME in $AWS_REGION..."
      ${pkgs.awscli}/bin/aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        $(if [ "$AWS_REGION" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=$AWS_REGION"; fi)
      echo "Bucket setup complete."
    '';
  in tf-json // { inherit apply destroy create-state-bucket; };
```

---

#### **`pushLambdaToAWS`**

This function pushes a Docker image for a Lambda function to AWS Elastic Container Registry (ECR). It
handles Docker authentication, tagging, and pushing the image.

```nix
pushLambdaToAWS =
  { pkgs, config, lambdaImg, registryName, oci-program ? pkgs.docker }:
  let
    awsRegion = config.provider.aws.region;
    buildPushScript = pkgs.writeShellScriptBin "build-push" ''
      echo "Logging in to ${registryName}"
      ${pkgs.awscli}/bin/aws ecr get-login-password --region ${awsRegion} | \
      ${pkgs.docker}/bin/docker login --username AWS --password-stdin "$1"
      echo "Pushing the Docker image..."
      ${
        lib.initech.pushDockerImage {
          inherit pkgs;
          dockerImage = lambdaImg;
        }
      }/bin/push-docker-image --image-name="$1" --tag="${lambdaImg.imageName}-latest"
    '';
  in
  buildPushScript;
```

---

## Conclusion

In this post, we explored how to integrate Terranix into a Snowfall-based flake to bridge the gap between
Nix's declarative system and Terraform's infrastructure-as-code capabilities. By combining Nix's modular
and reusable approach with Terranix, you can simplify infrastructure management, reduce redundancy, and
streamline your workflows.

We covered the essentials of using Terranix, from creating basic configurations to leveraging options
for module customization. Additionally, we discussed advanced topics like integrating Nix-built artifacts
into Terraform workflows, such as Lambda functions or EC2 instances. These techniques demonstrate how
tightly coupling Nix and Terraform can yield a more efficient and maintainable infrastructure ecosystem.

Terranix opens new possibilities for unifying application and infrastructure deployments under a single,
declarative framework. Whether you're a seasoned Terraform user or new to Nix, this approach can make
managing cloud infrastructure more approachable and powerful.

Looking ahead, I’ll continue exploring how Nix can further enhance cloud infrastructure management. In
future posts, we’ll delve into extending these concepts to EC2 deployments and other real-world scenarios.
Stay tuned for more insights in the _Nix in the Wild_ series!
