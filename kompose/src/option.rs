use std::path::PathBuf;

#[derive(clap::Parser, Debug)]
pub struct GlobalOptions {
    #[arg(long, global = true, value_enum, default_value_t)]
    pub color: clap::ColorChoice,

    /////module path global scope
    //#[arg(long, short = 's', global = true, default_value_t)]
    //pub scope: String,
    #[arg(long = "debug", global = true, default_value_t)]
    pub debug: bool,

    /// Adds a directory to search for imports in.
    #[arg(long, short = 'I', global = true)]
    pub import_path: Vec<PathBuf>,
}
