---
layout: side-title
side: left
titlewidth: is-4
align: rm-lt
color: dark
title: Code Example
---

:: title ::

A shell to a Container

:: content ::

````md magic-move
```nix
# Make a list of packages we might want in our environment
envPkgs = [pkgs.cowsay pkgs.figlet];
```

```nix
# Create a simple shell script that does something
script = pkgs.writeShellScriptBin "demo" ''
  echo "Nix the Planet!" | cowsay
'';
```

```nix
# Or you can specify the package in the script
script = pkgs.writeShellScriptBin "demo" ''
  cowsay "Nix the Planet!" | figlet | ${pkgs.lolcat}/bin/lolcat
'';
```

```nix
# Put that script into some environment
env = pkgs.buildEnv {
  name = "flashy-env";
  paths = envPkgs ++ [script];
};
```

```nix
# Use that environment in a DevShell
devShells.${system}.default = pkgs.mkShell {
  packages = [env];
};

# Or make a Docker container with it
packages.${system}.container = pkgs.dockerTools.buildImage {
  name = "flashy-env";
  tag = "latest";
  contents = [env];
  config.Cmd = ["demo"];
};
```

```nix
{
  description = "Example Flake that uses the same environment in a DevShell as in a Dockt Container";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs, }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    envPkgs = [pkgs.cowsay pkgs.figlet];
    script = pkgs.writeShellScriptBin "demo" ''
      cowsay "Nix the Planet!" | figlet | ${pkgs.lolcat}/bin/lolcat
    '';
    env = pkgs.buildEnv {
      name = "flashy-env";
      paths = envPkgs ++ [script];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [env];
    };
    packages.${system}.container = pkgs.dockerTools.buildImage {
      name = "flashy-env";
      tag = "latest";
      contents = [env];
      config.Cmd = ["demo"];
    };
  };
}
```
````
