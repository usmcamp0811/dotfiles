use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;
use tabled::{Table, Tabled};
use uuid::Uuid;

#[derive(Tabled, Clone, Debug, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub title: String,
    pub body: String,
    pub status: TaskStatus,
    pub created_at: DateTime<Utc>,
}

#[derive(PartialEq, Serialize, Deserialize, Debug, Clone)]
pub enum TaskStatus {
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

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_emoji())
    }
}

impl FromStr for TaskStatus {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "todo" => Ok(TaskStatus::ToDo),
            "doing" => Ok(TaskStatus::Doing),
            "review" => Ok(TaskStatus::Review),
            "done" => Ok(TaskStatus::Done),
            _ => Err(format!("Invalid status: {}", s)),
        }
    }
}

impl Task {
    // Constructor method
    pub fn new(title: String, body: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            title,
            body,
            status: TaskStatus::ToDo,
            created_at: Utc::now(),
        }
    }

    // make task competet
    pub fn set_status(&mut self, status: TaskStatus) -> &mut Self {
        self.status = status;
        self
    }
}
