
---
theme: ./themes/slidev-theme-neversink
layout: center
class: full-cover-slide text-center
color: dark
routerMode: hash
lineNumbers: true
neversink_string: "Nix: Taming the Wild West of Codebases"
colorSchema: light
title: Nix
---

:: title ::

# From Git Repo to Nix Package


:: content ::

````md magic-move
```nix
# Define the source of your package
src = pkgs.fetchFromGitHub {
  owner = "example";
  repo = "my-tool";
  rev = "v1.0.0";
  hash = "sha256-...";
};
```

```nix
# Define a basic build using mkDerivation
myTool = pkgs.stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";
  src = src;

  buildPhase = "true";  # if it's prebuilt
  installPhase = ''
    mkdir -p $out/bin
    cp my-tool $out/bin/
  '';
};
```

```nix
# Or use a build helper like buildGoModule
myTool = pkgs.buildGoModule {
  pname = "my-tool";
  version = "1.0.0";
  src = src;
  vendorHash = "sha256-...";
};
```

```nix
# Export it from your flake
packages.${system}.default = myTool;
apps.${system}.default = {
  type = "app";
  program = "${myTool}/bin/my-tool";
};
```

```nix 
{
  description = "Flake that builds a binary from a GitHub repo";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs, }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    src = pkgs.fetchFromGitHub {
      owner = "example";
      repo = "my-tool";
      rev = "v1.0.0";
      hash = "sha256-...";
    };
    myTool = pkgs.buildGoModule {
      pname = "my-tool";
      version = "1.0.0";
      src = src;
      vendorHash = "sha256-...";
    };
  in {
    packages.${system}.default = myTool;
    apps.${system}.default = {
      type = "app";
      program = "${myTool}/bin/my-tool";
    };
  };
}
```

````

