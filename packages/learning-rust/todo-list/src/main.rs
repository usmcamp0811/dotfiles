mod task;
mod task_manager;
use crate::task_manager::TaskManager;

fn main() {
    let mut manager = TaskManager::new();

    let id1 = manager.add_task("Learn Rust".to_string());
    let id2 = manager.add_task("Build a todo app".to_string());

    // manager.list_tasks();
    //
    // println!("\nMarking first task as complete...\n");
    // manager.complete_task(id1);
    //
    // manager.list_tasks();
}
