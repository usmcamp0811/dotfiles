pub mod cli;
pub mod task;
pub mod task_manager;
pub mod tui;
use std::env;

pub fn run() {
    // cli::run();
    let filename = env::var("TODO_FILE").unwrap_or_else(|_| "/home/mcamp/.todo.json".to_string());
    let mut manager = task_manager::TaskManager::load_from_file(&filename)
        .unwrap_or_else(|_| task_manager::TaskManager::new());
    if let Err(err) = tui::run_tui(&mut manager) {
        eprintln!("TUI Error: {}", err);
    }
    if let Err(e) = manager.save_to_file(&filename) {
        eprintln!("Error saving tasks: {}", e);
    }
}
