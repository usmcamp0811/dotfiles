use crate::task::Task;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, Read};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct TaskManager {
    tasks: HashMap<Uuid, Task>,
}

impl TaskManager {
    pub fn new() -> Self {
        Self {
            tasks: HashMap::new(),
        }
    }

    // add new tasks to the task manager
    pub fn add_task(&mut self, title: String) -> Uuid {
        let task = Task::new(title);
        let id = task.id;
        self.tasks.insert(id, task);
        id
    }

    // complete a task
    pub fn complete_task(&mut self, id: &Uuid) {
        if let Some(task) = self.tasks.get_mut(&id) {
            println!("Completing task {:?}", task);
            task.mark_complete();
        } else {
            println!("Task not found");
        }
    }

    // remove the task
    pub fn remove_task(&mut self, id: &Uuid) {
        if self.tasks.remove(id).is_some() {
            println!("Task {} was deleted...", id);
        } else {
            println!("Task not found...");
        }
    }

    // list all tasks
    pub fn list_tasks(&self) {
        for task in self.tasks.values() {
            println!(
                "ID: {} \t Title: {} \t Complete: {}",
                task.id, task.title, task.completed,
            );
        }
    }

    pub fn save_to_file(&self, filename: &str) -> std::io::Result<()> {
        let json = serde_json::to_string_pretty(&self)?;
        std::fs::write(filename, json)?;
        Ok(())
    }

    pub fn load_from_file(filename: &str) -> std::io::Result<Self> {
        let json = std::fs::read_to_string(filename)?;
        let task_manager: TaskManager = serde_json::from_str(&json)?;
        Ok(task_manager)
    }
}
