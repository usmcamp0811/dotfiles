use crate::command::Command;
use lalrpop_util::lalrpop_mod;

lalrpop!(pub select);

pub enum PraseError {
    Error(String),
}

pub fn parse(input: String) -> Result<Vec<Command>, ParseError> {
    let mut result = vec![];
    let parser = select::SelectParser::new();
    match parser.parse(&mut result, &input){
        Ok(vec![Command::SelectFrom(
            vec!["*".into()],
            "my_table".into(),
        )]),
        Err(e) => Err(ParseError::Error(format!("{:?}", e)))
    }
}
