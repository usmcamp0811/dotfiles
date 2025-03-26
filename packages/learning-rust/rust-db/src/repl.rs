use crate::command::CommandResult;
use crate::parser::{parse, ParseError};
use crate::vm::VirtualMachine;
use std::io::{self, Write};
use std::{collections::HashMap, ops::AddAssign};
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
                    CommandResult::RetrievedDataSuccess(t) => self.print_table(&t),
                    CommandResult::VoidSuccess => println!("OK"),
                    CommandResult::Error(e) => println!("Command Error: {}", e),
                },
                Err(ParseError::Error(e)) => println!("Parse error: {}", e),
            }
        }
    }

    fn print_table(&self, table: &crate::table::Table) {
        let cols = &table.selected_columns;
        let mut widths: HashMap<&String, usize> = HashMap::new();

        for col in cols {
            if let Some(col_data) = table.columns.get(col) {
                let max_val_len = col_data
                    .iter()
                    .map(|d| format!("{:?}", d).len())
                    .max()
                    .unwrap_or(0);
                widths.insert(col, col.len().max(max_val_len));
            } else {
                widths.insert(col, col.len());
            }
        }

        // Header
        for col in cols {
            print!(
                "{:>width$} ",
                col,
                width = widths.get(col).copied().unwrap_or(8)
            );
        }
        println!();

        // Rows
        let row_count = table.columns.values().next().map(|v| v.len()).unwrap_or(0);
        for i in 0..row_count {
            for col in cols {
                let val = table.columns.get(col).and_then(|v| v.get(i));
                match val {
                    Some(d) => print!(
                        "{:>width$}  ",
                        format!("{:?}", d),
                        width = widths.get(col).copied().unwrap_or(8)
                    ),
                    None => print!(
                        "{:>width$}  ",
                        "",
                        width = widths.get(col).copied().unwrap_or(8)
                    ),
                }
            }
            println!();
        }
    }
}
