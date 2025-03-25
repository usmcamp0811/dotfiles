pub enum Command {
    SelectFrom(Vec<String>, String), // (Columns, table_name)
    Stub,
}

pub enum CommandResult {
    RetrievedDataSuccess(crate::table::Table),
    VoidSuccess,
    Error(String),
}
