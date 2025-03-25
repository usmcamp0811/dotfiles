use crate::command::CommandResult;
use crate::praser::{parse, ParseError};
use crate::vm::VirtualMachine;
use std::io::{self, Write};
// use std::string::ParseError;

pub struct Repl {
    buffer: String,
    database: VirtualMachine,
}

impl Repl {
    pub fn new() -> Self {
        Self {
            buffer: String::new(),
            database: VirtualMachine::new(),
        }
    }

    pub fn run(&mut self) {
        loop {
            print!("->> ");
            io::stdout().flush().unwrap();
            let mut input = String::new();
            if io::stdin().read_line(&mut input).is_err() {
                println!("Failed to read input");
                continue;
            }

            self.buffer.push_str(&input);
            if !self.buffer.trim_end().ends_with(';') {
                continue;
            }

            let query = std::mem::take(&mut self.buffer);
            if query.trim().to_lowercase() == "exit;" {
                break;
            }

            match parse(query) {
                Ok(commands) => match self.database.execute(commands) {
                    CommandResult::RetrievedDataSuccess(t) => println!("{:?}", t),
                    CommandResult::VoidSuccess => println!("OK"),
                    CommandResult::Error(e) => println!("Command Error: {}", e),
                },
                Err(ParseError::Error(e)) => println!("Parse error: {}", e),
            }
        }
    }
}
