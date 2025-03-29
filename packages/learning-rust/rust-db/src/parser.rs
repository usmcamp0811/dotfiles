use lalrpop_util::lalrpop_mod;
use std::{collections::HashMap, ops::AddAssign};

lalrpop_mod!(sql);

use crate::command::Command;

pub enum ParseError {
    Error(String),
}

pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let mut columns = vec![];
    let mut values = vec![];
    let mut table = String::new();
    let mut schema = HashMap::new();
    let parser = sql::StatementParser::new();
    let result = sql::StatementParser::new().parse(
        &mut columns,
        &mut table,
        &mut schema,
        &mut values,
        &input,
    );

    match result {
        Ok(_) => {
            if !schema.is_empty() {
                Ok(vec![Command::CreateTable(table, schema)])
            } else if !values.is_empty() && columns.len() > 0 {
                Ok(vec![Command::InsertInto(table, columns, values)])
            } else if !values.is_empty() && columns.len() == 1 {
                Ok(vec![Command::DeleteWhere(
                    table,
                    columns[0].clone(),
                    values[0].clone(),
                )])
            } else {
                Ok(vec![Command::SelectFrom(columns, table)])
            }
        }
        Err(e) => Err(ParseError::Error(format!("{:?}", e))),
    }
}
