use crate::table::DataType;
use lalrpop_util::lalrpop_mod;
use std::{collections::HashMap, ops::AddAssign};

lalrpop_mod!(sql);

use crate::command::Command;

pub enum ParseError {
    Error(String),
}

pub enum Statement {
    Select {
        columns: Vec<String>,
        table: String,
        where_clause: Option<(String, DataType)>,
    },
    Insert {
        table: String,
        columns: Vec<String>,
        values: Vec<DataType>,
    },
    Create {
        table: String,
        schema: HashMap<String, DataType>,
    },
    Update {
        table: String,
        set_column: String,
        set_value: DataType,
        where_column: String,
        where_value: DataType,
    },
    Delete {
        table: String,
        where_column: String,
        where_value: DataType,
    },
}

pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let statement = sql::StatementParser::new()
        .parse(&input)
        .map_err(|e| ParseError::Error(format!("{:?}", e)))?;

    match statement {
        Statement::Select {
            columns,
            table,
            where_clause,
        } => Ok(vec![Command::SelectFrom(columns, table, where_clause)]),
        Statement::Insert {
            table,
            columns,
            values,
        } => Ok(vec![Command::InsertInto(table, columns, values)]),
        Statement::Create { table, schema } => Ok(vec![Command::CreateTable(table, schema)]),
        Statement::Update {
            table,
            set_column,
            set_value,
            where_column,
            where_value,
        } => Ok(vec![Command::UpdateWhere {
            table,
            set_column,
            set_value,
            where_column,
            where_value,
        }]),
        Statement::Delete {
            table,
            where_column,
            where_value,
        } => Ok(vec![Command::DeleteWhere(table, where_column, where_value)]),
    }
}
