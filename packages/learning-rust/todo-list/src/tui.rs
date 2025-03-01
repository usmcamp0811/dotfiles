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
    let mut input_body = String::new();
    let mut current_field = 0; // 0 = title, 1 = body

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
                let title_style = if current_field == 0 {
                    Style::default().fg(Color::White).bg(Color::Blue)
                } else {
                    Style::default().fg(Color::White).bg(Color::Black)
                };

                let body_style = if current_field == 1 {
                    Style::default().fg(Color::White).bg(Color::Blue)
                } else {
                    Style::default().fg(Color::White).bg(Color::Black)
                };

                let title_input = Paragraph::new(format!("> {}", input_title))
                    .block(Block::default().title("Title").borders(Borders::ALL))
                    .style(title_style);

                let body_input = Paragraph::new(format!("> {}", input_body))
                    .block(Block::default().title("Body").borders(Borders::ALL))
                    .style(body_style);

                let popup_area = Layout::default()
                    .direction(Direction::Vertical)
                    .margin(5)
                    .constraints([
                        Constraint::Percentage(30),
                        Constraint::Percentage(5),
                        Constraint::Percentage(30),
                    ])
                    .split(frame.area());
                frame.render_widget(Clear, popup_area[1]);

                frame.render_widget(Clear, popup_area[2]);
                frame.render_widget(title_input, popup_area[1]);
                frame.render_widget(body_input, popup_area[2]);
            }
        })?;

        // Handle user input
        if event::poll(std::time::Duration::from_millis(200))? {
            if let Event::Key(key) = event::read()? {
                if input_mode {
                    match key.code {
                        KeyCode::Tab | KeyCode::Down => {
                            // Move to the next field
                            current_field = 1;
                        }
                        KeyCode::Up => {
                            // Move back to the previous field
                            current_field = 0;
                        }
                        KeyCode::Enter => {
                            if current_field == 0 {
                                current_field = 1;
                            } else if current_field == 1 {
                                if !input_title.trim().is_empty() {
                                    manager.add_task(input_title.clone(), Some(input_body.clone()));
                                    input_body.clear();
                                    input_title.clear();
                                }
                            }
                            input_mode = false; // Close popup
                            current_field = 0; // reset to title for next input
                        }
                        KeyCode::Esc => {
                            input_mode = false; // Close popup without saving
                            input_title.clear();
                        }
                        KeyCode::Backspace => {
                            if current_field == 0 {
                                input_title.pop(); // Remove last character
                            } else if current_field == 1 {
                                input_body.pop(); // Remove last character
                            }
                        }
                        KeyCode::Char(c) => {
                            if current_field == 0 {
                                input_title.push(c); // Append typed character
                            } else if current_field == 1 {
                                input_body.push(c); // Append typed character
                            }
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
