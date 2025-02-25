pub mod cli;
pub mod task;
pub mod task_manager;
pub mod tui;
use std::env;

pub fn run() {
    // cli::run();
    let filename = env::var("TODO_FILE").unwrap_or_else(|_| "/home/mcamp/.todo.json".to_string());
    let manager = task_manager::TaskManager::load_from_file(&filename)
        .unwrap_or_else(|_| task_manager::TaskManager::new());
    if let Err(err) = tui::run_tui(manager) {
        eprintln!("TUI Error: {}", err);
    }
}
