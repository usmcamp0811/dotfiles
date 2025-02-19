use chrono::{DateTime, Utc};
use uuid::Uuid;

pub struct Task {
    pub id: Uuid,
    pub title: String,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
}

impl Task {
    // Constructor method
    pub fn new(title: String) -> Self {
        println!("\nCreated: {}\n", title);
        Self {
            id: Uuid::new_v4(),
            title,
            completed: false,
            created_at: Utc::now(),
        }
    }
    // make task competet
    pub fn mark_complete(&mut self) {
        self.completed = true;
    }

    // check if task is done
    pub fn is_done(&self) -> bool {
        self.completed
    }
}
