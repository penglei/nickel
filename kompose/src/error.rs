use nickel_lang_core::{
    error::report::{ColorOpt, ErrorFormat},
    error::Diagnostic,
    eval::cache::lazy::CBNCache,
    program::Program,
};
pub type CliResult<T> = Result<T, Error>;

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct IOError(pub String);

pub enum Error {
    Program {
        program: Program<CBNCache>,
        error: nickel_lang_core::error::Error,
    },
    Io {
        error: IOError,
    },
    Render {
        source_dir_without_definition: String,
    },
    Repl {
        error: nickel_lang_core::repl::InitError,
    },
}

pub trait ResultErrorExt<T> {
    fn report_with_program(self, program: Program<CBNCache>) -> CliResult<T>;
}

impl<T> ResultErrorExt<T> for Result<T, nickel_lang_core::error::Error> {
    fn report_with_program(self, program: Program<CBNCache>) -> CliResult<T> {
        self.map_err(|error| Error::Program { program, error })
    }
}

impl Error {
    /// Report this error on the standard error stream.
    pub fn report(self, format: ErrorFormat, color: ColorOpt) {
        let report_standalone = |main_label: &str, msg: Option<String>| {
            use nickel_lang_core::{
                cache::{Cache, ErrorTolerance},
                error::report::report as core_report,
            };

            let mut dummy_cache = Cache::new(ErrorTolerance::Tolerant);
            let diagnostic = Diagnostic::error()
                .with_message(main_label)
                .with_notes(msg.into_iter().collect());

            core_report(&mut dummy_cache, diagnostic, format, color);
        };
        match self {
            Error::Program { mut program, error } => program.report(error, format),
            Error::Io { error } => {
                report_standalone("IO error", Some(error.0));
            }
            Error::Render {
                source_dir_without_definition,
            } => {
                eprintln!(
                    "no definition.ncl in source directory: \"{}\"",
                    source_dir_without_definition
                )
            }
            Error::Repl { error } => {
                use nickel_lang_core::repl::InitError;
                match error {
                    InitError::Stdlib => {
                        report_standalone("failed to initialize the standard library", None)
                    }
                    InitError::ReadlineError(msg) => {
                        report_standalone("failed to initialize the terminal interface", Some(msg))
                    }
                }
            }
        }
    }
}

impl From<std::io::Error> for IOError {
    fn from(error: std::io::Error) -> IOError {
        IOError(error.to_string())
    }
}

impl From<std::io::Error> for Error {
    fn from(error: std::io::Error) -> Self {
        Error::Io {
            error: error.into(),
        }
    }
}

impl From<nickel_lang_core::repl::InitError> for Error {
    fn from(error: nickel_lang_core::repl::InitError) -> Self {
        Error::Repl { error }
    }
}
