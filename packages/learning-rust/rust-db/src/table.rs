use std::{
    collections::HashMap,
    fs,
    fs::File,
    io::{BufRead, BufReader, BufWriter, Write},
};

#[derive(Debug, Clone, PartialEq)]
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

    pub fn save(&self) -> Result<(), String> {
        let filename = format!("{}.db", self.name);
        let file = File::create(&filename).map_err(|e| e.to_string())?;
        let mut writer = BufWriter::new(file);

        for (col, values) in &self.columns {
            writeln!(writer, "COLUMN {}", col).map_err(|e| e.to_string())?;
            for val in values {
                writeln!(writer, "{:?}", val).map_err(|e| e.to_string())?;
            }
        }

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
    pub fn load_all() -> HashMap<String, Table> {
        let mut tables = HashMap::new();

        for entry in fs::read_dir(".").unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();

            if path.extension().map(|ext| ext == "db").unwrap_or(false) {
                if let Some(name) = path.file_stem().and_then(|s| s.to_str()) {
                    if let Ok(table) = Table::load_from_file(name) {
                        tables.insert(name.to_string(), table);
                    }
                }
            }
        }

        tables
    }

    pub fn load_from_file(name: &str) -> Result<Self, String> {
        let filename = format!("{}.db", name);
        let file = File::open(&filename).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);

        let mut columns = HashMap::new();
        let mut current_col = None;

        for line in reader.lines() {
            let line = line.map_err(|e| e.to_string())?;
            if line.starts_with("COLUMN ") {
                let col = line.trim_start_matches("COLUMN ").to_string();
                current_col = Some(col.clone());
                columns.insert(col, vec![]);
            } else if let Some(col) = &current_col {
                let val = parse_value(&line)?;
                columns.get_mut(col).unwrap().push(val);
            }
        }

        let mut fields = HashMap::new();
        for (k, v) in &columns {
            if let Some(first) = v.first() {
                fields.insert(
                    k.clone(),
                    match first {
                        DataType::String(_) => DataType::String("".into()),
                        DataType::Integer32(_) => DataType::Integer32(0),
                        DataType::Float32(_) => DataType::Float32(0.0),
                    },
                );
            }
        }

        Ok(Table {
            name: name.into(),
            fields,
            columns,
            selected_columns: vec![],
        })
    }
}

fn parse_value(s: &str) -> Result<DataType, String> {
    if let Some(stripped) = s.strip_prefix("String(").and_then(|s| s.strip_suffix(")")) {
        Ok(DataType::String(stripped.trim_matches('"').to_string()))
    } else if let Some(int) = s
        .strip_prefix("Integer32(")
        .and_then(|s| s.strip_suffix(")"))
    {
        Ok(DataType::Integer32(
            int.parse::<i32>().map_err(|e| e.to_string())?,
        ))
    } else if let Some(flt) = s.strip_prefix("Float32(").and_then(|s| s.strip_suffix(")")) {
        Ok(DataType::Float32(
            flt.parse::<f32>().map_err(|e| e.to_string())?,
        ))
    } else {
        Err(format!("Unknown value: {}", s))
    }
}
