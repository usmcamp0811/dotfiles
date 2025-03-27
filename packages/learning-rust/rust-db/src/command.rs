use std::{collections::HashMap, ops::AddAssign};

pub enum Command {
    SelectFrom(Vec<String>, String), // (Columns, table_name)
    CreateTable(String, HashMap<String, crate::table::DataType>),
    Stub,
}

pub enum CommandResult {
    RetrievedDataSuccess(crate::table::Table),
    VoidSuccess,
    Error(String),
}
