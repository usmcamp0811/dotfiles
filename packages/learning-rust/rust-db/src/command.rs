use crate::table::DataType;
use std::{collections::HashMap, ops::AddAssign};

#[derive(Debug, PartialEq)]
pub enum Command {
    SelectFrom(Vec<String>, String, Option<(String, DataType)>),
    CreateTable(String, HashMap<String, crate::table::DataType>),
    InsertInto(String, Vec<String>, Vec<crate::table::DataType>),
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
