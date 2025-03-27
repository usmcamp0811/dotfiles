use lalrpop_util::lalrpop_mod;
use std::{collections::HashMap, ops::AddAssign};

lalrpop_mod!(sql);

use crate::command::Command;

pub enum ParseError {
    Error(String),
}

pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let mut columns = vec![];
    let mut table = String::new();
    let mut schema = HashMap::new();
    let parser = sql::StatementParser::new();
    let result = parser.parse(&mut columns, &mut table, &mut schema, &input);

    match result {
        Ok(_) => {
            if !schema.is_empty() {
                Ok(vec![Command::CreateTable(table, schema)])
            } else {
                Ok(vec![Command::SelectFrom(columns, table)])
            }
        }
        Err(e) => Err(ParseError::Error(format!("{:?}", e))),
    }
}
