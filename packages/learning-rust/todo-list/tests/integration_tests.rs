#[cfg(test)]
mod tests {
    use super::*;
    use todo_list::task_manager::TaskManager;

    #[test]
    fn test_add_task() {
        let mut manager = TaskManager::new();
        let id = manager.add_task("Test task".to_string());
        assert!(manager.tasks.contains_key(&id));
    }
}
