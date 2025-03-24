mod command;
mod parser;
mod repl;
mod table;
// mod vm;

fn main() {
    repl::Repl::new().run();
}
