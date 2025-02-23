use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tabled::{Table, Tabled};
use uuid::Uuid;

#[derive(Tabled, Clone, Debug, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub title: String,
    #[tabled(display = "format_completed")]
    pub completed: bool,
    pub created_at: DateTime<Utc>,
}

fn format_completed(completed: &bool) -> String {
    if *completed {
        "✅".into()
    } else {
        "🟥".into()
    }
}
impl Task {
    // Constructor method
    pub fn new(title: String) -> Self {
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
