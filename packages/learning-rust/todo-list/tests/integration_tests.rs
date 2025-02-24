#[cfg(test)]
mod tests {
    use super::*;
    use todo_list::task_manager::TaskManager;

    #[test]
    fn test_add_task() {
        let mut manager = TaskManager::new();
        let _id = manager.add_task("Test task".to_string());
        assert_eq!(manager.task_count(), 1);
    }
}
