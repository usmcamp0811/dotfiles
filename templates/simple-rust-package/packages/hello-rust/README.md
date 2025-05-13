# Rust Basics

This guide walks you through the basics of Rust with a hands-on approach.

## 1. Create a New Rust Project

```sh
cargo new my_project
cd my_project
```

This initializes a new Rust project with a `Cargo.toml` file and a `src/main.rs` file.

## 2. Rust REPL

Rust has a REPL-like tool called [`evcxr`](https://github.com/google/evcxr) that allows you to execute Rust code interactively.

### Install `evcxr` (Nix):

```sh
nix shell nixpkgs#rustc nixpkgs#cargo nixpkgs#evcxr

```

### Start the REPL:

```sh
evcxr
```

Now you can execute Rust code interactively:

```rust
>> let x = 42;
>> println!("{}", x);
42
```

It supports multi-line definitions, external crates, and even async code.

## 3. Basic Syntax

Edit `src/main.rs`:

```rust
fn main() {
    println!("Hello, Rust!");
}
```

Run it:

```sh
cargo init
cargo run
```

## 4. Variables and Mutability

```rust
fn main() {
    let x = 5; // Immutable by default
    let mut y = 10; // Mutable
    y += 1;
    println!("x: {}, y: {}", x, y);
}
```

## 5. Data Types

```rust
fn main() {
    let int_num: i32 = 42;
    let float_num: f64 = 3.14;
    let is_active: bool = true;
    let character: char = 'R';
    println!("{} {} {} {}", int_num, float_num, is_active, character);
}
```

## 6. Functions

```rust
fn add(a: i32, b: i32) -> i32 {
    a + b // Implicit return (no semicolon)
}

fn main() {
    let sum = add(5, 3);
    println!("Sum: {}", sum);
}
```

## 7. Control Flow

```rust
fn main() {
    let number = 7;

    if number % 2 == 0 {
        println!("Even");
    } else {
        println!("Odd");
    }
}
```

## 8. Loops

### `for` loop:

```rust
fn main() {
    for i in 1..=5 {
        println!("Iteration: {}", i);
    }
}
```

### `while` loop:

```rust
fn main() {
    let mut count = 0;
    while count < 5 {
        println!("Count: {}", count);
        count += 1;
    }
}
```

### Infinite `loop`:

```rust
fn main() {
    let mut n = 0;
    loop {
        println!("n: {}", n);
        n += 1;
        if n == 5 { break; }
    }
}
```

## 9. Ownership & Borrowing

```rust
fn main() {
    let s1 = String::from("Rust");
    let s2 = &s1; // Borrowing
    println!("{}", s2);
}
```

## 10. Structs & Enums

### Structs

```rust
struct Person {
    name: String,
    age: u8,
}

fn main() {
    let person = Person { name: String::from("Alice"), age: 30 };
    println!("{} is {} years old.", person.name, person.age);
}
```

### Enums

```rust
enum Direction {
    Up,
    Down,
    Left,
    Right,
}

fn main() {
    let dir = Direction::Up;
    match dir {
        Direction::Up => println!("Going Up"),
        Direction::Down => println!("Going Down"),
        _ => println!("Other direction"),
    }
}
```

## 11. Traits (Like Interfaces)

```rust
trait Speak {
    fn speak(&self);
}

struct Dog;
impl Speak for Dog {
    fn speak(&self) {
        println!("Woof!");
    }
}

fn main() {
    let dog = Dog;
    dog.speak();
}
```

## 12. Error Handling

### Using `Result`:

```rust
use std::fs::File;

fn main() {
    let file = File::open("non_existent.txt");
    match file {
        Ok(f) => println!("File opened: {:?}", f),
        Err(e) => println!("Error: {}", e),
    }
}
```

## 13. Concurrency with Threads

```rust
use std::thread;
use std::time::Duration;

fn main() {
    let handle = thread::spawn(|| {
        for i in 1..=5 {
            println!("Thread: {}", i);
            thread::sleep(Duration::from_millis(500));
        }
    });

    handle.join().unwrap();
}
```

---

This should give you a solid grasp of Rust basics. From here, consider:

- [Rust Book](https://doc.rust-lang.org/book/)
- [Rustlings](https://github.com/rust-lang/rustlings) (interactive exercises)
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/) (practical snippets)

Happy coding!
