use std::rc::Rc;
use std::{fs, io::Cursor, io::Write, path::PathBuf};

use itertools::Itertools;
use nickel_lang_core::{
    error::{Error, IOError},
    eval::cache::lazy::CBNCache,
    program::Program,
    serialize::{self, ExportFormat},
    term::{
        array::{Array, ArrayAttrs},
        RichTerm, Term,
    },
};

use crate::{
    error::{CliResult, ResultErrorExt},
    option::GlobalOptions,
};

/// Available export formats.
// If you add or remove variants, remember to update the CLI docs in `src/bin/nickel.rs'
#[derive(Copy, Clone, Eq, PartialEq, Debug, Default, clap::ValueEnum)]
pub enum LocalExportFormat {
    Raw,
    #[default]
    Json,
    MiJson,
    Ncl,
    Yaml,
    Toml,
}

#[derive(clap::Parser, Debug)]
pub struct ExportCommand {
    #[arg(long, short, value_enum, default_value_t)]
    format: LocalExportFormat,

    /// Output file. Standard output by default
    #[arg(short, long)]
    output: Option<PathBuf>,

    files: Vec<PathBuf>,

    #[arg(long = "as-list")]
    list: bool,
}

impl ExportCommand {
    pub fn run(self, global: GlobalOptions) -> CliResult<()> {
        let mut import_files: Vec<_> = self.files.iter().unique().collect();
        import_files.sort();

        let mut program = if self.list {
            let mut import_terms = Vec::with_capacity(import_files.len());
            for import_file in import_files.iter() {
                import_terms.push(RichTerm::from(Term::Import(import_file.into())));
            }
            let source_code = RichTerm::from(Term::Array(
                Array::new(Rc::from(import_terms)),
                ArrayAttrs::default(),
            ))
            .to_string();

            let src = Cursor::new(source_code);
            Program::new_from_source(src, "<generated (as list)>", std::io::stderr())
        } else {
            match import_files.as_slice() {
                [] => Program::new_from_stdin(std::io::stderr()),
                [p] => Program::new_from_file(p, std::io::stderr()),
                files => Program::new_from_files(files, std::io::stderr()),
            }
        }?;

        program.color_opt = global.color.into();
        program.add_import_paths(global.import_path.iter());

        if let Ok(nickel_path) = std::env::var("NICKEL_IMPORT_PATH") {
            program.add_import_paths(nickel_path.split(':'));
        }

        self.export(&mut program).report_with_program(program)
    }

    fn export(self, program: &mut Program<CBNCache>) -> Result<(), Error> {
        let rt = program.eval_full_for_export()?;

        if self.format == LocalExportFormat::Ncl {
            let mut output_writer = if let Some(file) = self.output {
                let file = fs::File::create(file).map_err(IOError::from)?;
                Box::new(file) as Box<dyn Write>
            } else {
                Box::new(std::io::stdout()) as Box<dyn Write>
            };
            output_writer.write_all(rt.to_string().as_bytes()).unwrap();
        } else {
            let format = match self.format {
                LocalExportFormat::Raw => ExportFormat::Raw,
                LocalExportFormat::Json => ExportFormat::Json,
                LocalExportFormat::MiJson => ExportFormat::MiJson,
                LocalExportFormat::Yaml => ExportFormat::Yaml,
                LocalExportFormat::Toml => ExportFormat::Toml,
                _ => ExportFormat::Json,
            };

            // We only add a trailing newline for JSON exports. Both YAML and TOML
            // exporters already append a trailing newline by default.
            let trailing_newline = format == ExportFormat::Json;

            serialize::validate(format, &rt)?;

            if let Some(file) = self.output {
                let mut file = fs::File::create(file).map_err(IOError::from)?;
                serialize::to_writer(&mut file, format, &rt)?;

                if trailing_newline {
                    writeln!(file).map_err(IOError::from)?;
                }
            } else {
                serialize::to_writer(std::io::stdout(), format, &rt)?;

                if trailing_newline {
                    println!();
                }
            }
        }

        Ok(())
    }
}
