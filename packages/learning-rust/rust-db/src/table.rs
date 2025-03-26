use std::{collections::HashMap, ops::AddAssign};

#[derive(Debug, Clone)]
pub enum DataType {
    String(String),
    Integer32(i32),
    Float32(f32),
}

#[derive(Debug, Clone)]
pub struct Table {
    pub name: String,
    pub fields: HashMap<String, DataType>,
    pub columns: HashMap<String, Vec<DataType>>,
    pub selected_columns: Vec<String>,
}

impl Table {
    pub fn save(&self, path: &str) -> Result<(), String> {
        // todo
        Ok(())
    }

    pub fn load(table_name: &str, selected_columns: Vec<String>) -> Result<Self, String> {
        if table_name != "test_table" {
            return Err(format!("Table '{}' not found", table_name));
        }
        let mut fields = HashMap::new();
        fields.insert("name".into(), DataType::String("".into()));
        fields.insert("age".into(), DataType::Integer32(0));

        let mut columns = HashMap::new();
        columns.insert(
            "name".into(),
            vec![DataType::Integer32(30), DataType::Integer32(25)],
        );

        Ok(Self {
            name: table_name.into(),
            fields,
            columns,
            selected_columns,
        })
    }
}
