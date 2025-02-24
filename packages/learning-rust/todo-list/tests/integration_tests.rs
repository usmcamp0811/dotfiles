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
}
