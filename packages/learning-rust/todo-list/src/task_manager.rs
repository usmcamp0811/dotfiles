use crate::task::Task;
use std::collections::HashMap;
use uuid::Uuid;

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

    // list all tasks
    pub fn list_tasks(&mut self) {
        for task in self.tasks.values() {
            println!("{}", task.title);
        }
    }
}
