use lalrpop_util::lalrpop_mod;

lalrpop_mod!(select);

use crate::command::Command;

#[derive(Debug)]
pub enum PraseError {
    Error(String),
}

#[derive(Debug)]
pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let mut result = vec![];
    let parser = select::SelectParser::new();
    parser
        .parse(&mut result, &input)
        .map(|_| vec![Command::SelectFrom(result, "my_table".into())])
        .map_err(|e| ParseError::Error(format!("{:?}", e)))
}
