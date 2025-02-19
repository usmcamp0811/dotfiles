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
    pub fn add_task(&mut self, title: String) {
        let task = Task::new(title);
        self.tasks.insert(task.id, task);
    }

    // complete a task
    pub fn complete_task(&mut self, id: Uuid) {}
}
