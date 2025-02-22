mod task;
mod task_manager;
use crate::task_manager::TaskManager;
use clap::Parser;
use serde::{Deserialize, Serialize};

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[arg(long, short, help = "Path to the input file")]
    filename: String,
}

fn main() {
    let args = Args::parse();
    let filename = args.filename;
    let mut manager = TaskManager::load_from_file(&filename).unwrap_or_else(|_| TaskManager::new());
    let id1 = manager.add_task("Learn Rust".to_string());
    let id2 = manager.add_task("Build a todo app".to_string());
    let id3 = manager.add_task("Make an interface for the app".to_string());
    let id4 = manager.add_task("Make a GUI for the app".to_string());

    println!("\nListing Tasks...");
    manager.list_tasks();

    println!("\nMarking first task as complete...");
    manager.complete_task(&id1);

    manager.remove_task(&id3);

    if let Err(e) = manager.save_to_file(&filename) {
        eprintln!("Error saving tasks: {}", e);
    }
}
