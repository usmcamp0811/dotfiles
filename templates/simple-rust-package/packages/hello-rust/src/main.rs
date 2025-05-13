
fn main() {
    println!("Hello, Rust!");

    println!("\nVariables and Mutability:");
    vars_example();

    println!("\nData Types:");
    data_types();

    println!("\nFunctions:");
    let sum = add(5,3);
    println!("Sum: {}", sum);

    println!("\nFor Loops:");
    floop();

    println!("\nWhile Loops:");
    wloop();

    println!("\nInfinite Loops:");
    iloop();

    println!("\nOwnership & Barrowing:");
    ownership();

    println!("\nStructs:");
    let person = Person { name: String::from("Alice"), age: 30};
    println!("{} is  {} years old.", person.name, person.age);

    println!("\nEnums:");
    enums();

    println!("\nTraits:");
    let dog = Dog;
    dog.speak();

    println!("\nError Handling:");
    error_handling();

    println!("\nConcurrenct with Threads:");
    cothreads();
}

fn vars_example() {
    let x = 5;
    let mut y = 10;
    y += 1;
    println!("x: {}, y: {}", x, y);
}

fn data_types(){
    let int_num: i32 = 42;
    let float_num: f64 = 3.14;
    let is_active: bool = true;
    let character: char = 'R';
    println!("Int32 => {}; Float64 => {}; Bool => {}; Char => {}", int_num, float_num, is_active, character);
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn floop() {
    for i in 1..=5{
        println!("Iteration: {}",i);
    }
}

fn wloop() {
    let mut n = 0;
    loop {
        println!("n: {}", n);
        n += 1;
        if n == 5 { break; }
    }

}

fn iloop() {
    let mut n = 0;
    loop {
        println!("n: {}", n);
        n += 1;
        if n == 5 { break; }
    }
}

fn ownership() {
    let s1 = String::from("Rust");
    let s2 = &s1;
    println!("{}", s2);
}

struct Person {
    name: String,
    age: u8,
}

enum Direction {
    Up, 
    Down,
    Left,
    Right,
}

fn enums(){
    let dir = Direction::Up;
    match dir {
        Direction::Up => println!("Going Up"),
        Direction::Down => println!("Going Down"),
        _ => println!("Other direction"),
    }
}

trait Speak {
    fn speak(&self);
}

struct Dog;
impl Speak for Dog {
    fn speak(&self){
        println!("Woof!");
    }
}

use std::fs::File;

fn error_handling(){
    let file = File::open("non_existent.txt");
    match file {
        Ok(f) => println!("File opened: {:?}", f),
        Err(e) => println!("Error: {}", e)
    }
    
}

use std::thread;
use std::time::Duration;

fn cothreads(){
    let handle = thread::spawn(|| {
        for i in 1..=5{
            println!("Thread: {}", i);
            thread::sleep(Duration::from_millis(500));
        }
    });
    handle.join().unwrap();
}
