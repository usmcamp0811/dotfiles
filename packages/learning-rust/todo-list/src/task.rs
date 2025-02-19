use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

pub struct Task {
    pub id: u32,
    pub title: String,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
}

impl Task {
    // Constructor method
    fn new(id: u32, title: String) -> Self {
        Self {
            id,
            title,
            completed: false,
        }
    }
    // make task competet p
    fn mark_complete(&mut self) {
        self.completed = true;
    }

    // check if task is done
    fn is_done(&self) -> bool {
        self.completed
    }
}
