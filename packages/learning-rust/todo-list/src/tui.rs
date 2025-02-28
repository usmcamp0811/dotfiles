use crate::task::TaskStatus;
use crate::task_manager::TaskManager;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::style::{Color, Style}; // Import Color and Style
use ratatui::widgets::Clear; // Import Clear widget
use ratatui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Terminal,
};
use std::io;
use uuid::Uuid;

pub fn run_tui(manager: &mut TaskManager) -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    // enter fullscreen
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = app_loop(&mut terminal, manager);
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
    let mut selected_column = 0; // 0 = ToDo, 1 = Doing, 2 = Review, 3 = Done
    let mut selected_task_indices = vec![0, 0, 0, 0]; // Track selected task in each column
    let mut input_mode = false;
    let mut input_title = String::new();

    let statuses = [
        TaskStatus::ToDo,
        TaskStatus::Doing,
        TaskStatus::Review,
        TaskStatus::Done,
    ];
    loop {
        terminal.draw(|frame| {
            let outer_layout = Layout::default()
                .direction(Direction::Vertical)
                .margin(1)
                .constraints([
                    Constraint::Min(10),   // Main task board
                    Constraint::Length(3), // Bottom section
                ])
                .split(frame.area());

            let kanban = Layout::default()
                .direction(Direction::Horizontal)
                .margin(2)
                .constraints([
                    Constraint::Percentage(25), // ToDo Column
                    Constraint::Percentage(25), // Doing Column
                    Constraint::Percentage(25), // Review Column
                    Constraint::Percentage(25), // Done Column
                ])
                .split(outer_layout[0]);

            let task_lists: Vec<Vec<ListItem>> = statuses
                .iter()
                .enumerate()
                .map(|(col, &ref status)| {
                    manager
                        .get_tasks()
                        .iter()
                        .filter(|task| task.status == *status)
                        .enumerate()
                        .map(|(idx, task)| {
                            let marker =
                                if col == selected_column && idx == selected_task_indices[col] {
                                    "▶"
                                } else {
                                    " "
                                };
                            ListItem::new(format!("{}{}", marker, task.title))
                        })
                        .collect()
                })
                .collect();

            let column_colors = [
                Color::Yellow, // ToDo
                Color::Green,  // Doing
                Color::Blue,   // Review
                Color::Red,    // Done
            ];
            let instructions =
                Paragraph::new("↑↓: Move | →: Change Status | i: Add Task | q: Quit")
                    .block(Block::default().title("Bottom").borders(Borders::ALL));

            for (col, task_item) in task_lists.iter().enumerate() {
                let list =
                    List::new(task_item.clone()).block(
                        Block::default()
                            .title(match col {
                                0 => "To Do",
                                1 => "Doing",
                                2 => "Review",
                                3 => "Done",
                                _ => unreachable!(),
                            })
                            .borders(Borders::ALL)
                            .style(Style::default().fg(Color::White).bg(
                                if col == selected_column {
                                    column_colors[col]
                                } else {
                                    Color::Reset
                                },
                            )),
                    );
                frame.render_widget(list, kanban[col]);
            }
            frame.render_widget(instructions, outer_layout[1]);

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
                    .split(frame.area());
                frame.render_widget(Clear, popup_area[1]);
                let input_box = Paragraph::new(format!("> {}", input_title)).block(
                    Block::default()
                        .title("Enter Task")
                        .borders(Borders::ALL)
                        .style(Style::default().fg(Color::White).bg(Color::Black)),
                );

                frame.render_widget(input_box, popup_area[1]);
            }
        })?;

        // Handle user input
        if event::poll(std::time::Duration::from_millis(200))? {
            if let Event::Key(key) = event::read()? {
                if input_mode {
                    match key.code {
                        KeyCode::Enter => {
                            if !input_title.trim().is_empty() {
                                manager.add_task(input_title.clone(), None); // Save task
                                input_title.clear();
                            }
                            input_mode = false; // Close popup
                        }
                        KeyCode::Esc => {
                            input_mode = false; // Close popup without saving
                            input_title.clear();
                        }
                        KeyCode::Backspace => {
                            input_title.pop(); // Remove last character
                        }
                        KeyCode::Char(c) => {
                            input_title.push(c); // Append typed character
                        }
                        _ => {}
                    }
                } else {
                    match key.code {
                        KeyCode::Char('q') => return Ok(()),
                        KeyCode::Char('i') => {
                            input_mode = true;
                            input_title.clear();
                        }
                        KeyCode::Left | KeyCode::Char('h') => {
                            if selected_column > 0 {
                                selected_column -= 1;
                            }
                        }
                        KeyCode::Right | KeyCode::Char('l') => {
                            if selected_column < 3 {
                                selected_column += 1;
                            }
                        }
                        KeyCode::Up | KeyCode::Char('k') => {
                            if selected_task_indices[selected_column] > 0 {
                                selected_task_indices[selected_column] -= 1;
                            }
                        }
                        KeyCode::Down | KeyCode::Char('j') => {
                            let num_tasks = manager
                                .get_tasks()
                                .iter()
                                .filter(|task| task.status == statuses[selected_column])
                                .count();
                            if selected_task_indices[selected_column] < num_tasks.saturating_sub(1)
                            {
                                selected_task_indices[selected_column] += 1;
                            }
                        }
                        KeyCode::Enter => {
                            let current_status = &statuses[selected_column];
                            if let Some(task) = manager
                                .get_tasks_mut()
                                .iter_mut()
                                .filter(|task| task.status == *current_status)
                                .nth(selected_task_indices[selected_column])
                            {
                                task.set_status(next_status(&task.status));
                            }
                        }

                        // KeyCode::Char('i') => {
                        //     input_mode = true;
                        //     input_title.clear();
                        // }
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
