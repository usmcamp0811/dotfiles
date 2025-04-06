use image::io::Reader as ImageReader;
use kitty_image::{Action, ActionTransmission, Command, Format, Medium, WrappedCommand};
use std::io::Cursor;
use std::io::{stdout, Write};
use std::thread::sleep;
use sysinfo::System;
use systemstat::{Platform, System as StatSystem};
use tempfile::NamedTempFile;
use whoami;

const IMAGE_DATA: &[u8] = include_bytes!("ega.png");

fn move_cursor_below_image(rows: u32) {
    // ANSI escape to move cursor down N lines
    write!(stdout(), "\x1b[{}B", rows).unwrap();
    stdout().flush().unwrap();
}

fn display_ega() {
    // Write embedded image to a temp file
    let img = ImageReader::new(Cursor::new(IMAGE_DATA))
        .with_guessed_format()
        .unwrap()
        .decode()
        .unwrap();

    let mut tmpfile = NamedTempFile::new().unwrap();
    tmpfile.write_all(IMAGE_DATA).unwrap();
    let path = tmpfile.path();

    let action = Action::TransmitAndDisplay(
        ActionTransmission {
            format: Format::Png,
            medium: Medium::Direct,
            width: 10, // or your actual width
            height: 5, // or your actual height
            ..Default::default()
        },
        kitty_image::ActionPut {
            columns: 10,
            rows: 5,
            move_cursor: true,
            ..Default::default()
        },
    );

    let mut command = Command::new(action);
    command.payload = IMAGE_DATA.to_vec().into();
    let command = WrappedCommand::new(command);
    command.send_chunked(&mut stdout()).unwrap();
}

fn main() {
    display_ega();
    let mut sys = System::new_all();
    let mut sysstat = StatSystem::new();
    sys.refresh_all();
    let username = whoami::username();
    let hostname = System::host_name().unwrap_or_default();
    let user_at_host = format!(
        "\x1b[34m{}\x1b[0m\x1b[37m@\x1b[0m\x1b[34m{}\x1b[0m",
        username, hostname
    );
    let line = "─".repeat(username.len() + 1 + hostname.len());
    const GREEN_BOLD: &str = "\x1b[1;32m";
    const RESET: &str = "\x1b[0m";
    println!("");
    println!("{}", user_at_host);
    println!("{}", line);

    println!(
        "{}OS:{}     {}",
        GREEN_BOLD,
        RESET,
        System::os_version().unwrap_or_default()
    );
    println!(
        "{}Kernel:{} {}",
        GREEN_BOLD,
        RESET,
        System::kernel_version().unwrap_or_default()
    );

    let uptime = System::uptime();
    let days = uptime / 86400;
    let hours = (uptime % 86400) / 3600;
    let minutes = (uptime % 3600) / 60;

    println!(
        "{}Uptime:{} {} days, {} hours, {} mins",
        GREEN_BOLD, RESET, days, hours, minutes
    );
    println!("{}CPU:{}    {}", GREEN_BOLD, RESET, sys.cpus()[0].brand());
    println!("{}Cores:{}  {}", GREEN_BOLD, RESET, sys.cpus().len());
    println!(
        "{}Memory:{} {:.2} GiB / {:.2} GiB",
        GREEN_BOLD,
        RESET,
        sys.used_memory() as f64 / 1024.0 / 1024.0 / 1024.0,
        sys.total_memory() as f64 / 1024.0 / 1024.0 / 1024.0
    );
    match sysstat.battery_life() {
        Ok(batt) => {
            let percent = batt.remaining_capacity * 100.0;
            let hours = batt.remaining_time.as_secs() / 3600;
            let minutes = (batt.remaining_time.as_secs() % 3600) / 60;

            let status = match sysstat.on_ac_power() {
                Ok(true) => "AC Connected",
                Ok(false) => "On Battery",
                Err(_) => "Unknown",
            };

            println!(
                "{}Battery:{} {:.0}% ({}h {}m) [{}]",
                GREEN_BOLD, RESET, percent, hours, minutes, status
            );
        }
        Err(e) => println!(""),
    }
}
