#[cfg(test)]
mod tests {
    use todo_list::task::TaskStatus;
    use todo_list::task_manager::TaskManager;

    #[test]
    fn test_add_task() {
        let mut manager = TaskManager::new();
        let _id = manager.add_task("Test task".to_string());
        assert_eq!(manager.count_all_tasks(), 1);
        assert_eq!(manager.count(TaskStatus::ToDo), 1);
        assert_eq!(manager.count(TaskStatus::Done), 0);
    }

    #[test]
    fn test_complete_task() {
        let mut manager = TaskManager::new();
        let _id = manager.add_task("Test task".to_string());
        assert_eq!(manager.count(TaskStatus::ToDo), 1);
        manager.complete_task(&_id);
        assert_eq!(manager.count(TaskStatus::ToDo), 0);
        assert_eq!(manager.count(TaskStatus::Done), 1);
    }

    #[test]
    fn test_task_action() {
        let mut manager = TaskManager::new();
        let _id = manager.add_task("Test task".to_string());
        assert_eq!(manager.count(TaskStatus::ToDo), 1);

        // Doing
        manager.task_action(&_id, TaskStatus::Doing);
        assert_eq!(manager.count(TaskStatus::ToDo), 0);
        assert_eq!(manager.count(TaskStatus::Doing), 1);
        assert_eq!(manager.count(TaskStatus::Review), 0);
        assert_eq!(manager.count(TaskStatus::Done), 0);

        // Review
        manager.task_action(&_id, TaskStatus::Review);
        assert_eq!(manager.count(TaskStatus::ToDo), 0);
        assert_eq!(manager.count(TaskStatus::Doing), 0);
        assert_eq!(manager.count(TaskStatus::Review), 1);

        // Done
        manager.task_action(&_id, TaskStatus::Done);
        assert_eq!(manager.count(TaskStatus::ToDo), 0);
        assert_eq!(manager.count(TaskStatus::Doing), 0);
        assert_eq!(manager.count(TaskStatus::Review), 0);
        assert_eq!(manager.count(TaskStatus::Done), 1);
    }
}
