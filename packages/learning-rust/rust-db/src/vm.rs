use crate::command::{Command, CommandResult};
use crate::table::DataType;
use crate::table::Table;
use std::{collections::HashMap, ops::AddAssign};

pub struct VirtualMachine {
    tables: HashMap<String, Table>,
}

impl VirtualMachine {
    pub fn new() -> Self {
        let mut tables = HashMap::new();
        let table = Table::load("test_table", vec!["name".into(), "age".into()])
            .unwrap_or_else(|_| panic!("Failed to preload 'test_table'"));
        tables.insert("test_table".into(), table);
        Self { tables }
    }

    pub fn execute(&self, commands: Vec<Command>) -> CommandResult {
        for command in commands {
            match command {
                Command::SelectFrom(cols, table_name) => { /* existing code */ }
                Command::CreateTable(table_name, schema) => {
                    // For now, return a placeholder error message.
                    return CommandResult::Error("CREATE TABLE not implemented yet".into());
                }
                Command::Stub => return CommandResult::VoidSuccess,
            }
        }
        CommandResult::Error("No command executed".into())
    }
}
