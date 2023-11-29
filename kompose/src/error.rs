use nickel_lang_core::{
    error::report::{ColorOpt, ErrorFormat},
    error::{Diagnostic, FileId, Files, IntoDiagnostics, ParseError},
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
    /// An invalid invocation of the CLI that couldn't be caught by the simple parsing provided by
    /// clap.
    CliUsage {
        program: Program<CBNCache>,
        error: CliUsageError,
    },
}

/// Errors related to mishandling the CLI.
pub enum CliUsageError {
    /// A parse error occurred when trying to parse a field path.
    FieldPathParseError { error: ParseError },
}

impl IntoDiagnostics<FileId> for CliUsageError {
    fn into_diagnostics(
        self,
        files: &mut Files<String>,
        stdlib_ids: Option<&Vec<FileId>>,
    ) -> Vec<Diagnostic<FileId>> {
        match self {
            CliUsageError::FieldPathParseError { error } => {
                let mut diags = IntoDiagnostics::into_diagnostics(error, files, stdlib_ids);
                diags.push(
                    Diagnostic::note()
                        .with_message("when parsing a field path on the command line")
                        .with_notes(vec![
                            "A field path must be a dot-separated list of fields. Special \
                            characters must be properly escaped, both for Nickel and for the \
                            shell."
                                .to_owned(),
                            "For example: a field path `config.\"$port\"` \
                            must be written `config.\\\"\\$port\\\"` or `'config.\"$port\"'` on \
                            a POSIX shell"
                                .to_owned(),
                        ]),
                );
                diags
            }
        }
    }
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
            Error::CliUsage { mut program, error } => {
                //eprintln!("{}", error);
                program.report(error, format)
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
