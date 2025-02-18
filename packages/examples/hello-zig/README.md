# Zig Basics

This guide walks you through the basics of Zig with a hands-on approach.

## 1. Create a New Zig Project

```sh
mkdir my_zig_project
cd my_zig_project
zig init-exe
```

This initializes a new Zig project with a `build.zig` file and a `src/main.zig` file.

## 2. Zig Syntax

Edit `src/main.zig`:

```zig
const std = @import("std");

pub fn main() void {
    std.debug.print("Hello, Zig!\n", .{});
}
```

Run it:

```sh
zig build run
```

## 3. Zig Variables and Mutability

```zig
const std = @import("std");

pub fn main() void {
    var x: i32 = 5; // Mutable variable
    x += 1;
    std.debug.print("x: {}\n", .{x});
}
```

## 4. Zig Functions

```zig
const std = @import("std");

fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn main() void {
    const sum = add(5, 3);
    std.debug.print("Sum: {}\n", .{sum});
}
```

## 5. Zig Control Flow

```zig
const std = @import("std");

pub fn main() void {
    const number = 7;
    if (number % 2 == 0) {
        std.debug.print("Even\n", .{});
    } else {
        std.debug.print("Odd\n", .{});
    }
}
```

## 6. Package Zig in Nix

Create a `flake.nix` file:

```nix
{
  description = "A Zig package";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system}.zig = pkgs.stdenv.mkDerivation {
      pname = "my_zig_project";
      version = "0.1.0";
      src = ./.;
      buildInputs = [ pkgs.zig ];
      buildPhase = "zig build";
      installPhase = "mkdir -p $out/bin; cp zig-out/bin/* $out/bin/";
    };
  };
}
```

---

This guide now covers Zig basics, including Nix packaging. From here, consider:

- [Zig Learn](https://ziglearn.org/)
- [Zig Language Reference](https://ziglang.org/documentation/master/)

Happy coding!
