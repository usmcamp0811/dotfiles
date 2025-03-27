use lalrpop_util::lalrpop_mod;

lalrpop_mod!(select);

use crate::command::Command;

pub enum ParseError {
    Error(String),
}

pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let mut columns = vec![];
    let mut table = String::new();
    let parser = select::SelectParser::new();
    match parser.parse(&mut columns, &mut table, &input) {
        Ok(_) => Ok(vec![Command::SelectFrom(columns, table)]),
        Err(e) => Err(ParseError::Error(format!("{:?}", e))),
    }
}
