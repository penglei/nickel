use std::env;
use std::fs::metadata;
use std::io::Write;
use std::path::PathBuf;
use std::{fs, io::Cursor, result::Result};

use indoc::indoc;
use lazy_static::lazy_static;
use nickel_lang_core::{
    error::Error,
    eval::cache::lazy::CBNCache,
    identifier::LocIdent,
    program::Program,
    serialize::{self, ExportFormat},
    term,
};
use regex::Regex;
use serde_json;

use crate::error;
use crate::error::{CliResult, ResultErrorExt};
use crate::option::GlobalOptions;

lazy_static! {
    static ref ASSIAGN_SYNTAX: Regex = Regex::new(
        r#"^(?<key>[\w\d"][\w\d-]*[\w\d"](?:\.[\w\d"][\w\d-]*[\w\d"]?)*)\s*=\s*(?<val>.+)$"#
    )
    .unwrap();
    static ref NUMBER: Regex = Regex::new(r"^[-+\d]\d*(.\d+)?$").unwrap();
    static ref NAIVE_COMPOUND: Regex = Regex::new(r#"^(?:\{.*\}|\[.*\]|\(.*\)|".*")$"#).unwrap();
    static ref IMPORT_FILE_VAL: Regex =
        Regex::new(r#"^@(?<file>.+\.(?:yaml|json|ncl|toml))$"#).unwrap();
    static ref PARSE_DATA_VAL: Regex =
        Regex::new(r#"^'(?<format>json|yaml):(?<content>.+)$"#).unwrap();
    static ref OBJECT_PATH: Regex = Regex::new(r"^(?:[-\w\d_]+(?:\.[-\w\d_]+)*)?$").unwrap();
}

#[derive(clap::Parser, Debug)]
pub struct InputOptions<ValueCombiner: clap::Args> {
    /// Input files
    files: Vec<PathBuf>,

    #[command(flatten)]
    pub value: ValueCombiner,
}

#[derive(clap::Parser, Debug)]
struct ValueOptions {
    ///  customize configuration values.
    ///
    ///      `-i k.apiserver image=X`
    ///
    ///       translate to:
    ///       {k.apiserver.input = {image | force = "X"}
    ///
    ///
    ///  value can also be loaded from file:
    ///
    ///      `-f k.apiserver '(import "./image.json")'`
    ///
    ///
    #[arg(long, short = 'i', num_args(1..=2), value_names = ["Object path", "EXPRESSION or ASSIGNMENT"])]
    inputs: Vec<String>,

    ///  object fragment
    ///
    ///      `-f k.apiserver spec.replicas=3`
    ///
    ///       translate to:
    ///
    ///       {k.apiserver.fragment = {spec.replicas | force = 3}}
    ///
    ///      `-f k.apiserver {spec.template.spec.namedContainers.app.image="X"}`
    ///
    ///       translate to:
    ///
    ///       {k.apiserver.fragment = {spec.template.spec.namedContainers.app.image="X"}}
    ///
    #[arg(long, short = 'f', num_args(1..=2), value_names = ["Object path", "EXPRESSION or ASSIGNMENT"])]
    fragments: Vec<String>,
}

pub trait ValueCombiner {
    fn combine<'a>(&'a self, partials: &'a mut Vec<String>) -> &mut Vec<String>;
}

#[derive(clap::Parser, Debug)]
pub struct RenderCommand {
    #[command(flatten)]
    input: InputOptions<ValueOptions>,

    /// Split component/object by component tree level depth to an separated output directory or file.
    #[arg(long, short = 's', value_name = "DEPTH", default_value_t = 0)]
    split_depth: u8,

    /// Seperate to standalone directory with the filename.
    /// If the option is unset, seperated outputs will be saved to a file named by the component/object node path name.
    #[arg(long, short = 'a', value_name = "FILENAME")]
    standalone_file: Option<String>,

    /// Filter components/objects subset by component path.
    ///
    /// e.g.
    /// if we define the component:
    ///
    ///   {
    ///      apiserver = {deployment = {..}, configmap = {..}, ..}
    ///      controller-manager = {deployment = {..}, configmap = {..}, ..}
    ///   }
    ///
    ///  `-p apiserver.deployment controller-manager.deployment` would
    ///   only render the two `deployment` objects in apiserver and controller-manager.
    ///
    /// You can also use '*' to match any component in one config level.
    /// In the example above, `*.deployment` has the same effect as the former.
    #[arg(long, short = 'p', default_values_t = ["*".to_string()])]
    projection: Vec<String>,

    /// Output file/directory.
    #[arg(short, long)]
    output: Option<PathBuf>,
}

#[allow(dead_code)]
fn convert_to_tuple_array(args: &Vec<String>) -> Vec<(String, String)> {
    args.chunks(2)
        .map(|chunk| (chunk[0].clone(), chunk[1].clone()))
        .collect()
}
fn parse_args_to_tuples(args: &Vec<String>) -> Vec<(String, String)> {
    let mut iter = args.iter();
    let mut pairs = vec![];

    loop {
        match iter.next() {
            Some(s) => {
                let is_key = OBJECT_PATH.is_match(s.as_str());
                let (key, val) = if is_key {
                    (s.as_str(), iter.next().unwrap().as_str())
                } else {
                    ("", s.as_str())
                };

                pairs.push((key.to_string(), val.to_string()))
            }
            None => {
                break;
            }
        };
    }

    pairs
    //vec![("".to_string(), "".to_string())]
}

#[derive(PartialEq)]
enum DefineType {
    InputValue,
    Fragment,
}

#[derive(PartialEq)]
enum SiloValueType {
    Primitive,
    Composite,
}

impl ValueOptions {
    fn gen_code<'a>(
        args: &Vec<String>,
        typ: &DefineType,
        partials: &'a mut Vec<String>,
    ) -> &'a mut Vec<String> {
        if args.is_empty() {
            return partials;
        }

        for (key, value) in parse_args_to_tuples(args).iter() {
            let field = (key, typ);

            use SiloValueType::*;
            let source = match ASSIAGN_SYNTAX.captures(value) {
                Some(caps) => {
                    let key = &caps["key"];
                    let val = match &caps["val"] {
                        v @ "true" | v @ "false" | v @ "null" => (Primitive, v.to_string()),
                        x => {
                            if NUMBER.is_match(x) {
                                (Primitive, x.to_string())
                            } else if NAIVE_COMPOUND.is_match(x) {
                                (Composite, x.to_string())
                            } else {
                                match IMPORT_FILE_VAL.captures(x) {
                                    Some(caps) => {
                                        let file = &caps["file"];
                                        //let format = caps.name("format").map_or("")
                                        (Composite, format!("import \"{}\"", file))
                                    }
                                    None => match PARSE_DATA_VAL.captures(x) {
                                        Some(caps) => {
                                            let format = &caps["format"].to_lowercase();
                                            let content = &caps["content"];

                                            let decoder = if format == "json" {
                                                "std.deserialize 'Json"
                                            } else if format == "yaml" {
                                                "std.deserialize 'Yaml"
                                            } else {
                                                ""
                                            };

                                            (Composite, format!("{} m%\"{}\"%", decoder, content))
                                        }

                                        None =>
                                        //如果不是 `数字`，不是 `{..}`, 不是 `[..]`, 不是  `(..)`，不是 `".."`，不是@file
                                        //则认为是字符串
                                        {
                                            (Primitive, format!("\"{}\"", x.replace("\"", "\\\"")))
                                        }
                                    },
                                }
                            }
                        }
                    };

                    let priority = match typ {
                        DefineType::Fragment => "force".to_string(),
                        DefineType::InputValue => {
                            //dbg!(field.0);
                            let path_depth = if field.0 == "" {
                                0
                            } else {
                                field.0.split('.').count()
                            };
                            //let path_depth = field.0.chars().filter(|c| *c == '.').count();
                            format!("priority {}", 900 + path_depth)
                        }
                    };

                    match val.0 {
                        Primitive => {
                            format!("{{ {} | {} = {} }}", key, priority, val.1)
                        }
                        Composite => {
                            format!("{{ {} = {} }}", key, val.1)
                        }
                    }
                }
                _ => match IMPORT_FILE_VAL.captures(value) {
                    Some(caps) => {
                        let file = &caps["file"];
                        format!("import \"{}\"", file)
                    }
                    None => value.clone(), //raw source
                },
            };

            let code_val = {
                let define_hint = match field.1 {
                    DefineType::Fragment => "fragment",
                    DefineType::InputValue => "input",
                };
                format!("{{ {} = {} }}", define_hint, source)
            };

            let code = if field.0 == "" {
                format!("({})", code_val)
            } else {
                format!("({{ {} = {} }})", field.0, code_val)
            };
            partials.push(code);
        }
        partials
    }
}
impl ValueCombiner for ValueOptions {
    //e.g. -i cluster_name=cls-foo  -f monitor.statefulset spec.replicas=3
    fn combine<'a>(&'a self, partials: &'a mut Vec<String>) -> &'a mut Vec<String> {
        let partials = Self::gen_code(&self.inputs, &DefineType::InputValue, partials);
        let partials = Self::gen_code(&self.fragments, &DefineType::Fragment, partials);
        return partials;
    }
}

const MAIN_SOURCE_NAME: &'static str = "<main(generated by cli)>";

fn prepare(main_source: &String) -> std::io::Result<Program<CBNCache>> {
    let src = Cursor::new(main_source);
    Program::new_from_source(src, MAIN_SOURCE_NAME, std::io::stderr())
}

impl RenderCommand {
    pub fn run(self, global: GlobalOptions) -> CliResult<()> {
        let mut srcfiles = vec![];
        for s in self.input.files.iter() {
            if metadata(&s)
                .map_err(|e| error::Error::Io {
                    error: error::IOError(format!(
                        "{}\n:\"{}\"",
                        e.to_string(),
                        s.to_str().unwrap(),
                    )),
                })?
                .is_dir()
            {
                let spkgfile = s.join("definition.ncl");
                if !metadata(&spkgfile).is_ok() {
                    return Err(error::Error::Render {
                        source_dir_without_definition: s.to_str().unwrap().to_string(),
                    });
                }

                let l: Vec<_> = s
                    .read_dir()?
                    .filter_map(|f| f.ok())
                    .filter(|f| match f.path().extension() {
                        None => false,
                        Some(ex) => ex == "ncl",
                    })
                    .map(|f| f.path())
                    .collect();
                srcfiles.extend(l);
            } else {
                srcfiles.push(s.to_path_buf());
            };
        }

        let mut partials: Vec<String> = srcfiles
            .iter()
            .map(|f| format!(r#"(import "{}")"#, f.to_str().unwrap().to_string()))
            .collect();

        let projection = serde_json::to_string(&self.projection).unwrap();
        let split_depth = self.split_depth;
        let partials = self.input.value.combine(&mut partials);
        let main_source = format!(
            "Comod.render {} {}\n[\n\t{}\n]",
            projection,
            split_depth,
            partials.join(",\n\t"),
        );

        if global.debug {
            eprintln!("##### debug #####");
            if let Ok(imports) = env::var("NICKEL_IMPORT_PATH") {
                eprintln!("import searching paths:");
                for p in imports.split(":") {
                    eprintln!("  {}", p);
                }
            }

            eprintln!(
                indoc! {"
            #{}#
            {}
            #{}#"},
                format!("{:-^1$}", MAIN_SOURCE_NAME, 40),
                main_source,
                "-".repeat(40),
            );
        }

        let mut program = prepare(&main_source)?;

        program.add_import_paths(global.import_path.into_iter()); //high priority
        if let Ok(nickel_path) = std::env::var("NICKEL_IMPORT_PATH") {
            program.add_import_paths(nickel_path.split(':'));
        }

        self.render(&mut program).report_with_program(program)
    }

    fn render(self, program: &mut Program<CBNCache>) -> Result<(), Error> {
        let rt = program.eval_full_for_export()?;

        let format = ExportFormat::Yaml;

        let work_dir = PathBuf::from(".");

        let ident_objs = LocIdent::from("objs");
        let ident_path = LocIdent::from("path");

        match rt.term.as_ref() {
            term::Term::Array(docs, _) => {
                let out_count = docs.len();
                let can_output_to_stdout = out_count == 1;

                //only one, we can output to stdout if output is unset.
                for (i, item) in docs.iter().enumerate() {
                    let is_last_out = out_count - 1 == i;
                    match item.term.as_ref() {
                        term::Term::Record(ref data) => {
                            let objs = data
                                .fields
                                .get(&ident_objs)
                                .unwrap()
                                .value
                                .as_ref()
                                .unwrap();

                            let path = data
                                .fields
                                .get(&ident_path)
                                .unwrap()
                                .value
                                .as_ref()
                                .unwrap();

                            let (mut output_writer, standalone_out) = if self.output.is_none()
                                && can_output_to_stdout
                            {
                                (Box::new(std::io::stdout()) as Box<dyn Write>, false)
                            } else {
                                let base = if let Some(ref output) = self.output {
                                    output
                                } else {
                                    &work_dir
                                };

                                let path = if let term::Term::Array(arr, _) = path.term.as_ref() {
                                    let acc = PathBuf::new();
                                    arr.iter().fold(acc, |mut acc, p| {
                                        if let term::Term::Str(s) = p.term.as_ref() {
                                            acc.push(s.as_ref());
                                            acc
                                        } else {
                                            acc
                                        }
                                    })
                                } else {
                                    panic!("path is not array");
                                };

                                let mut file = base.join(path);

                                if let Some(ref sfname) = self.standalone_file {
                                    file.push(sfname);
                                } else {
                                    file.set_extension(format!("{}", format));
                                };

                                std::fs::create_dir_all(file.parent().unwrap()).unwrap();

                                (
                                    Box::new(fs::File::create(&file).unwrap()) as Box<dyn Write>,
                                    true,
                                )
                            };

                            match objs.term.as_ref() {
                                term::Term::Array(objs, _) => {
                                    let obj_count = objs.len();
                                    for (j, obj) in objs.iter().enumerate() {
                                        serialize::to_writer(&mut output_writer, format, obj)?;
                                        let is_last_obj = obj_count - 1 == j;

                                        let is_last = (standalone_out && is_last_obj)
                                            || (!standalone_out && is_last_out && is_last_obj);
                                        if !is_last {
                                            output_writer.write_all(b"---\n").unwrap();
                                        }
                                    }
                                }
                                _ => {
                                    panic!("objs is not array")
                                }
                            }
                        }
                        _ => {
                            panic!("output array item is not record")
                        }
                    }
                }
            }
            _ => {
                panic!("output is not array");
            }
        };

        Ok(())
    }
}
