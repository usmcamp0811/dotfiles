use crate::task::TaskStatus;
use crate::task_manager::TaskManager;
use clap::{CommandFactory, Parser, Subcommand, ValueEnum};
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

    #[command(subcommand)]
    action: Option<TaskAction>,
}

#[derive(Debug, Subcommand)]
enum TaskAction {
    Add {
        title: String,
    },
    List,
    Update {
        #[arg(value_parser = clap::value_parser!(Uuid))]
        id: Uuid,

        #[arg(value_enum)]
        status: TaskStatus,
    },
    Delete {
        #[arg(value_parser = clap::value_parser!(Uuid))]
        id: Uuid,
    },
    Finish {
        #[arg(value_parser = clap::value_parser!(Uuid))]
        id: Uuid,
    },
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

pub fn run() {
    let args = Args::parse();
    let filename = expand_tilde(args.filename);
    let mut manager = TaskManager::load_from_file(&filename).unwrap_or_else(|_| TaskManager::new());

    if std::env::args().len() == 1 {
        Args::command().print_help().unwrap();
        std::process::exit(1);
    }

    match args.action {
        Some(TaskAction::Update { id, status }) => match manager.task_action(&id, status) {
            Ok(_) => println!("Task updated successfully."),
            Err(e) => eprintln!("{}", e),
        },

        Some(TaskAction::List) => {
            manager.list_tasks();
        }

        Some(TaskAction::Add { title }) => {
            _ = manager.add_task(title, None);
            println!("Task added succesfully!")
        }

        Some(TaskAction::Delete { id }) => manager.remove_task(&id),
        Some(TaskAction::Finish { id }) => manager.complete_task(&id),

        None => {
            Args::command().print_help().unwrap();
            std::process::exit(1);
        }
    }
    if let Err(e) = manager.save_to_file(&filename) {
        eprintln!("Error saving tasks: {}", e);
    }
}
