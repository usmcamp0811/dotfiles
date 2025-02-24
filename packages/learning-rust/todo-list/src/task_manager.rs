use crate::task::{Task, TaskStatus};
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::{self, Read};
use std::{collections::HashMap, ops::AddAssign};
use tabled::{builder::Builder, settings::Style};
use tabled::{Table, Tabled};
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
            task.set_status(TaskStatus::Done);
        } else {
            println!("Task not found");
        }
    }

    pub fn task_action(&mut self, id: &Uuid, action: TaskStatus) -> Result<(), String> {
        self.tasks
            .get_mut(id)
            .map(|task| {
                task.set_status(action);
            })
            .ok_or_else(|| format!("Task with ID {} not found.", id))
    }

    pub fn task_count(&self) -> usize {
        self.tasks.len()
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
        let tasks: Vec<Task> = self.tasks.values().cloned().collect();
        let table = Table::new(tasks).with(Style::modern_rounded()).to_string();

        println!("{}", table);
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
