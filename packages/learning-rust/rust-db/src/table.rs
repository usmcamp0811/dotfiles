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
        Err("Table::load not implemented yet".into())
    }
}
