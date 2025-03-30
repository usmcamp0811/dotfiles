use crate::table::DataType;
use lalrpop_util::lalrpop_mod;
use std::{collections::HashMap, ops::AddAssign};

lalrpop_mod!(sql);

use crate::command::Command;

#[derive(Debug)]
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::command::Command;
    use crate::table::DataType;

    #[test]
    fn test_select_basic() {
        let input = "select name from users;".to_string();
        let result = parse(input).unwrap();
        assert_eq!(
            result,
            vec![Command::SelectFrom(
                vec!["name".into()],
                "users".into(),
                None
            )]
        );
    }

    #[test]
    fn test_select_where() {
        let input = r#"select name from users where age = 30;"#.to_string();
        let result = parse(input).unwrap();
        assert_eq!(
            result,
            vec![Command::SelectFrom(
                vec!["name".into()],
                "users".into(),
                Some(("age".into(), DataType::Integer32(30)))
            )]
        );
    }

    #[test]
    fn test_insert() {
        let input = r#"insert into users (name, age) values ("matt", 38);"#.to_string();
        let result = parse(input).unwrap();
        assert_eq!(
            result,
            vec![Command::InsertInto(
                "users".into(),
                vec!["name".into(), "age".into()],
                vec![DataType::String("matt".into()), DataType::Integer32(38)],
            )]
        );
    }
}
