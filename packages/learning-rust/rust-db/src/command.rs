use crate::table::DataType;
use std::{collections::HashMap, ops::AddAssign};

pub enum Command {
    SelectFrom(Vec<String>, String), // (Columns, table_name)
    CreateTable(String, HashMap<String, crate::table::DataType>),
    InsertInto(String, Vec<String>, Vec<crate::table::DataType>), // table, columns, values
    DeleteWhere(String, String, DataType),
    Stub,
}

pub enum CommandResult {
    RetrievedDataSuccess(crate::table::Table),
    VoidSuccess,
    Error(String),
}
