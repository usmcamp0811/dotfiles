mod task;
mod task_manager;
use crate::task_manager::TaskManager;
use clap::{CommandFactory, Parser};
use dirs::home_dir;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

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

    #[arg(long, short, help = "Task UUID")]
    id: Option<String>,

    #[arg(long, short, help = "Text for the Task Title")]
    title: Option<String>,

    #[arg(long, short, help = "List all Tasks")]
    list: bool,

    #[arg(long, short, help = "Remove a Task by UUID")]
    remove: bool,

    #[arg(long, short, help = "Complete task")]
    complete: bool,
}

// Handle tildes in file paths
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
    let mut manager = TaskManager::load_from_file(&filename).unwrap_or_else(|_| TaskManager::new());

    if std::env::args().len() == 1 {
        Args::command().print_help().unwrap();
        std::process::exit(1);
    }

    if let Some(title) = &args.title {
        let id = manager.add_task(title.to_string());
        println!("Created Task: {}", id);
    }

    if let Some(id) = &args.id {
        match Uuid::parse_str(id) {
            Ok(uuid) => {
                if args.remove {
                    manager.remove_task(&uuid);
                }
                if args.complete {
                    manager.complete_task(&uuid);
                }
            }
            Err(e) => eprintln!("Invalid UUID Provided {}", e),
        }
    }

    if args.list {
        manager.list_tasks();
    }

    if let Err(e) = manager.save_to_file(&filename) {
        eprintln!("Error saving tasks: {}", e);
    }
}
