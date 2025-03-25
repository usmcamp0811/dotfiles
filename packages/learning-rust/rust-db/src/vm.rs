use crate::command::{Command, CommandResult};
use crate::table::DataType;
use crate::table::Table;

pub struct VirtualMachine;

impl VirtualMachine {
    pub fn new() -> Self {
        Self
    }

    pub fn execute(&self, commands: Vec<Command>) -> CommandResult {
        for command in commands {
            match command {
                Command::SelectFrom(cols, table_name) => match Table::load(&table_name, cols) {
                    Ok(table) => return CommandResult::RetrievedDataSuccess(table),
                    Err(e) => return CommandResult::Error(e),
                },
                Command::Stub => return CommandResult::VoidSuccess,
            }
        }

        CommandResult::Error("No command executed".into())
    }
}
