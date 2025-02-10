# Loops in Nix: A Comprehensive Guide

## Introduction

Nix is a functional programming language, meaning it does not have traditional imperative loops like
Python or Julia. Instead, looping is done using recursion and built-in higher-order functions such as
`map`, `listToAttrs`, and `fold`. This guide will start with basic looping constructs and build up to
a complex example, comparing each step to equivalent Python and Julia code.

---

## 1. Basic Looping with `map`

### Nix

```nix
map (x: x * 2) [1 2 3 4 5]
```

**Result:** `[2 4 6 8 10]`

### Python Equivalent

```python
list(map(lambda x: x * 2, [1, 2, 3, 4, 5]))
```

### Julia Equivalent

```julia
map(x -> x * 2, [1, 2, 3, 4, 5])
```

---

## 2. Using `listToAttrs` for Key-Value Pair Generation

### Nix

```nix
listToAttrs (map (x: { name = x; value = x * x; }) [1 2 3])
```

**Result:** `{ 1 = 1; 2 = 4; 3 = 9; }`

### Python Equivalent

```python
{ x: x * x for x in [1, 2, 3] }
```

### Julia Equivalent

```julia
Dict(x => x^2 for x in [1, 2, 3])
```

---

## 3. Recursion-Based Looping (Functional Approach)

### Nix

```nix
let
  factorial = n: if n == 0 then 1 else n * factorial (n - 1);
in
factorial 5
```

**Result:** `120`

### Python Equivalent

```python
def factorial(n):
    return 1 if n == 0 else n * factorial(n - 1)

factorial(5)
```

### Julia Equivalent

```julia
factorial(n) = n == 0 ? 1 : n * factorial(n - 1)
factorial(5)
```

---

## 4. Folding Over a List (`foldl` / `foldr`)

### Nix

```nix
foldl (acc: x: acc + x) 0 [1 2 3 4 5]
```

**Result:** `15`

### Python Equivalent

```python
from functools import reduce
reduce(lambda acc, x: acc + x, [1, 2, 3, 4, 5], 0)
```

### Julia Equivalent

```julia
reduce(+, [1, 2, 3, 4, 5])
```

---

## 5. Complex Example: Generating a Package Set with Custom Attributes

### Nix

```nix
let
  packages = [ "vim" "git" "htop" ];
  mkPackage = name: {
    name = name;
    value = {
      pname = name;
      version = "1.0";
      buildInputs = [ "gcc" "make" ];
    };
  };
  packageSet = listToAttrs (map mkPackage packages);
in
packageSet
```

**Result:**

```nix
{
  git = { pname = "git"; version = "1.0"; buildInputs = [ "gcc" "make" ]; };
  htop = { pname = "htop"; version = "1.0"; buildInputs = [ "gcc" "make" ]; };
  vim = { pname = "vim"; version = "1.0"; buildInputs = [ "gcc" "make" ]; };
}
```

### Python Equivalent

```python
packages = ["vim", "git", "htop"]

def mkPackage(name):
    return name, {"pname": name, "version": "1.0", "buildInputs": ["gcc", "make"]}

packageSet = dict(map(mkPackage, packages))
```

### Julia Equivalent

```julia
packages = ["vim", "git", "htop"]
mkPackage(name) = name => Dict("pname" => name, "version" => "1.0", "buildInputs" => ["gcc", "make"])
packageSet = Dict(mkPackage.(packages))
```

---

## Conclusion

Nix relies on recursion and higher-order functions instead of traditional loops. Understanding `map`,
`listToAttrs`, and `fold` will allow you to manipulate data effectively. By comparing with Python and
Julia, you can see how similar concepts exist across different paradigms, even when syntax differs. Happy
coding in Nix!
