use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tabled::{Table, Tabled};
use uuid::Uuid;

#[derive(Tabled, Clone, Debug, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub title: String,
    pub status: TaskStatus,
    pub created_at: DateTime<Utc>,
}

enum TaskStatus {
    ToDo,
    Doing,
    Review,
    Done,
}

impl TaskStatus {
    fn as_emoji(&self) -> &str {
        match self {
            TaskStatus::ToDo => "🟥",
            TaskStatus::Doing => "🟧",
            TaskStatus::Review => "🟪",
            TaskStatus::Done => "✅",
        }
    }
}

impl Task {
    // Constructor method
    pub fn new(title: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            title,
            status: TaskStatus::ToDo,
            created_at: Utc::now(),
        }
    }

    // make task competet
    pub fn mark_complete(&mut self) {
        self.status = TaskStatus::Done;
    }

    // check if task is done
    pub fn is_done(&self) -> bool {
        if self.status == TaskStatus::Done {
            true
        } else {
            false
        }
    }
}
