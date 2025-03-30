use crate::table::DataType;
use std::{collections::HashMap, ops::AddAssign};

pub enum Command {
    SelectFrom(Vec<String>, String), // (Columns, table_name)
    CreateTable(String, HashMap<String, crate::table::DataType>),
    InsertInto(String, Vec<String>, Vec<crate::table::DataType>), // table, columns, values
    DeleteWhere(String, String, DataType),
    UpdateWhere {
        table: String,
        set_column: String,
        set_value: DataType,
        where_column: String,
        where_value: DataType,
    },
}

pub enum CommandResult {
    RetrievedDataSuccess(crate::table::Table),
    VoidSuccess,
    Error(String),
}
