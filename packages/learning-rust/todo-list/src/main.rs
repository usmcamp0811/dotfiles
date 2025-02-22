mod task;
mod task_manager;
use crate::task_manager::TaskManager;
use clap::Parser;
use dirs::home_dir;
use serde::{Deserialize, Serialize};

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[arg(
        long,
        short,
        help = "Path to the input file",
        default_value = "~/.todo.json"
    )]
    filename: String,

    #[arg(long, short, help = "Text for the Task Title", required = true)]
    title: String,
}

fn expand_tilde(path: String) -> String {
    if path.starts_with("~") {
        if let Some(home) = home_dir() {
            return path.replacen("~", home.to_str().unwrap(), 1);
        }
    }
    path
}

fn main() {
    let args = Args::parse();
    let filename = expand_tilde(args.filename);
    let title = args.title;
    let mut manager = TaskManager::load_from_file(&filename).unwrap_or_else(|_| TaskManager::new());
    manager.add_task(title);

    println!("\nListing Tasks...");
    manager.list_tasks();

    if let Err(e) = manager.save_to_file(&filename) {
        eprintln!("Error saving tasks: {}", e);
    }
}
