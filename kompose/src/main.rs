mod error;
mod export;
mod option;
mod render;
mod repl;

use nickel_lang_core::error::report;
use nickel_lang_core::error::report::ColorOpt;
use std::process::ExitCode;

use crate::export::ExportCommand;
use crate::option::GlobalOptions;
use crate::render::RenderCommand;
use crate::repl::ReplCommand;

#[derive(clap::Parser, Debug)]
#[command(name = "kp")]
#[command(author, about, long_about = None)]
struct Cli {
    #[command(flatten)]
    global: GlobalOptions,

    #[command(subcommand)]
    command: L2Command,
}

#[derive(clap::Subcommand, Debug)]
enum L2Command {
    /// Render kompose objects to yaml. Multiple objects will be render to (YAML Multi Documents)
    #[command(about = "render objects to yaml multi documents", long_about)]
    Render(RenderCommand),

    /// Exports the result to a different format
    Export(ExportCommand),

    /// Starts a Nickel REPL session
    Repl(ReplCommand),
}

fn main() -> ExitCode {
    let cli = <Cli as clap::Parser>::parse();

    let result = match cli.command {
        L2Command::Render(render) => render.run(cli.global),
        L2Command::Export(export) => export.run(cli.global),
        L2Command::Repl(repl) => repl.run(cli.global),
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            error.report(report::ErrorFormat::Text, ColorOpt::default());
            ExitCode::FAILURE
        }
    }
}
