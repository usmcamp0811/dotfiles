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
    pub fn select(&self, selected_columns: Vec<String>) -> Result<Self, String> {
        for col in &selected_columns {
            if !self.columns.contains_key(col) {
                return Err(format!("Column '{}' not found", col));
            }
        }

        Ok(Self {
            name: self.name.clone(),
            fields: self.fields.clone(),
            columns: self.columns.clone(),
            selected_columns,
        })
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
            vec![
                DataType::String("Alice".into()),
                DataType::String("Bob".into()),
            ],
        );
        columns.insert(
            "age".into(),
            vec![DataType::Integer32(30), DataType::Integer32(25)],
        );
        for col in &selected_columns {
            if !columns.contains_key(col) {
                return Err(format!(
                    "Column '{}' not found in table '{}'",
                    col, table_name
                ));
            }
        }

        Ok(Self {
            name: table_name.into(),
            fields,
            columns,
            selected_columns,
        })
    }
}
