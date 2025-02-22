mod task;
mod task_manager;
use crate::task_manager::TaskManager;
use serde::{Deserialize, Serialize};

fn main() {
    let filename = "todo.json";
    let mut manager = TaskManager::load_from_file(filename).unwrap_or_else(|_| TaskManager::new());
    let id1 = manager.add_task("Learn Rust".to_string());
    let id2 = manager.add_task("Build a todo app".to_string());
    let id3 = manager.add_task("Make an interface for the app".to_string());
    let id4 = manager.add_task("Make a GUI for the app".to_string());

    println!("\nListing Tasks...");
    manager.list_tasks();

    println!("\nMarking first task as complete...");
    manager.complete_task(&id1);

    manager.remove_task(&id3);

    if let Err(e) = manager.save_to_file("todo.json") {
        eprintln!("Error saving tasks: {}", e);
    }
}
