use crate::task::TaskStatus;
use crate::task_manager::TaskManager;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Terminal,
};
use std::io;
use uuid::Uuid;

pub fn run_tui(mut manager: TaskManager) -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    // enter fullscreen
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = app_loop(&mut terminal, &mut manager);
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

fn app_loop<B: Backend>(terminal: &mut Terminal<B>, manager: &mut TaskManager) -> io::Result<()> {
    let mut selected_index = 0;
    let mut input_mode = false;
    let mut input_text = String::new();

    loop {
        terminal.draw(|frame| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .margin(2)
                .constraints([
                    Constraint::Percentage(80), // Task List
                    Constraint::Percentage(20), // Instructions
                ])
                .split(frame.size());

            // Convert tasks into selectable list
            let tasks: Vec<ListItem> = manager
                .get_tasks()
                .iter()
                .enumerate()
                .map(|(i, task)| {
                    let marker = if i == selected_index { "▶" } else { " " };
                    ListItem::new(format!("{} [{}] {}", marker, task.status, task.title))
                })
                .collect();

            let list =
                List::new(tasks).block(Block::default().title("Todo List").borders(Borders::ALL));

            let instructions =
                Paragraph::new("↑↓: Move | →: Change Status | i: Add Task | q: Quit")
                    .block(Block::default().borders(Borders::ALL));

            frame.render_widget(list, chunks[0]);
            frame.render_widget(instructions, chunks[1]);

            // Render input popup if active
            if input_mode {
                let popup_area = Layout::default()
                    .direction(Direction::Vertical)
                    .margin(5)
                    .constraints([
                        Constraint::Percentage(30),
                        Constraint::Percentage(40),
                        Constraint::Percentage(30),
                    ])
                    .split(frame.size());

                let input_box = Paragraph::new(format!("> {}", input_text))
                    .block(Block::default().title("Enter Task").borders(Borders::ALL));

                frame.render_widget(input_box, popup_area[1]);
            }
        })?;

        // Handle user input
        if event::poll(std::time::Duration::from_millis(200))? {
            if let Event::Key(key) = event::read()? {
                if input_mode {
                    match key.code {
                        KeyCode::Enter => {
                            if !input_text.trim().is_empty() {
                                manager.add_task(input_text.clone()); // Save task
                                input_text.clear();
                            }
                            input_mode = false; // Close popup
                        }
                        KeyCode::Esc => {
                            input_mode = false; // Close popup without saving
                            input_text.clear();
                        }
                        KeyCode::Backspace => {
                            input_text.pop(); // Remove last character
                        }
                        KeyCode::Char(c) => {
                            input_text.push(c); // Append typed character
                        }
                        _ => {}
                    }
                } else {
                    match key.code {
                        KeyCode::Char('q') => return Ok(()),
                        KeyCode::Char('i') => {
                            input_mode = true;
                            input_text.clear();
                        }
                        KeyCode::Up | KeyCode::Char('k') => {
                            if selected_index > 0 {
                                selected_index -= 1;
                            }
                        }
                        KeyCode::Down | KeyCode::Char('j') => {
                            if selected_index < manager.get_tasks().len().saturating_sub(1) {
                                selected_index += 1;
                            }
                        }
                        KeyCode::Right | KeyCode::Char('l') => {
                            if let Some(task) = manager.get_tasks_mut().get_mut(selected_index) {
                                task.set_status(next_status(&task.status));
                            }
                        }
                        _ => {}
                    }
                }
            }
        }
    }
}

fn next_status(current: &TaskStatus) -> TaskStatus {
    match current {
        TaskStatus::ToDo => TaskStatus::Doing,
        TaskStatus::Doing => TaskStatus::Review,
        TaskStatus::Review => TaskStatus::Done,
        TaskStatus::Done => TaskStatus::ToDo,
    }
}
