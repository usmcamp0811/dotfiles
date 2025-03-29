use crate::command::{Command, CommandResult};
use crate::table::DataType;
use crate::table::Table;
use std::{collections::HashMap, ops::AddAssign};

pub struct VirtualMachine {
    tables: HashMap<String, Table>,
}

impl VirtualMachine {
    pub fn new() -> Self {
        let tables = Table::load_all();
        Self { tables }
    }

    pub fn execute(&mut self, commands: Vec<Command>) -> CommandResult {
        for command in commands {
            match command {
                Command::SelectFrom(cols, table_name) => {
                    if let Some(table) = self.tables.get(&table_name) {
                        return table
                            .select(cols)
                            .map(CommandResult::RetrievedDataSuccess)
                            .unwrap_or_else(|e| CommandResult::Error(e));
                    } else {
                        return CommandResult::Error(format!("Unknown table '{}'", table_name));
                    }
                }

                Command::CreateTable(name, schema) => {
                    if self.tables.contains_key(&name) {
                        return CommandResult::Error(format!("Table '{}' already exists", name));
                    }

                    let table = Table {
                        name: name.clone(),
                        fields: schema.clone(),
                        columns: schema.keys().map(|k| (k.clone(), vec![])).collect(),
                        selected_columns: schema.keys().cloned().collect(),
                    };

                    self.tables.insert(name.clone(), table);
                    self.tables
                        .get(&name)
                        .unwrap()
                        .save()
                        .unwrap_or_else(|e| eprintln!("Failed to save: {}", e));
                    return CommandResult::VoidSuccess;
                }

                Command::InsertInto(table, columns, values) => {
                    if let Some(t) = self.tables.get_mut(&table) {
                        for (col, val) in columns.into_iter().zip(values.into_iter()) {
                            t.columns.entry(col).or_insert_with(Vec::new).push(val);
                            t.save()
                                .unwrap_or_else(|e| eprintln!("Failed to save table: {}", e));
                        }
                        return CommandResult::VoidSuccess;
                    } else {
                        return CommandResult::Error(format!("Table '{}' not found", table));
                    }
                }

                Command::DeleteWhere(table, column, value) => {
                    if let Some(t) = self.tables.get_mut(&table) {
                        if let Some(vec) = t.columns.get_mut(&column) {
                            let mut indices_to_remove = vec
                                .iter()
                                .enumerate()
                                .filter(|(_, v)| *v == &value)
                                .map(|(i, _)| i)
                                .collect::<Vec<_>>();
                            indices_to_remove.sort_by(|a, b| b.cmp(a));
                            for idx in indices_to_remove {
                                for col_vals in t.columns.values_mut() {
                                    if idx < col_vals.len() {
                                        col_vals.remove(idx);
                                    }
                                }
                            }
                            t.save()
                                .unwrap_or_else(|e| eprint!("Failed to save after delete: {}", e));
                            return CommandResult::VoidSuccess;
                        }
                    }
                    return CommandResult::Error(format!(
                        "Table or column not found: {}.{}",
                        table, column
                    ));
                }

                Command::Stub => return CommandResult::VoidSuccess,
            }
        }

        CommandResult::Error("No command executed".into())
    }
}
