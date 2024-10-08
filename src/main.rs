mod engine;
mod utils;
mod tests;

use std::{
    env,
    sync::Mutex
};
use {
    engine::engine::Engine,
    utils::{
        typescript::process_file,
        logutil::{print_c, colors,styles, log},
        helper::on_de_initialize
    }
};
use lazy_static::lazy_static;
use boa_engine::JsResult;

lazy_static! {
    static ref DEBUG: Mutex<bool> = Mutex::new(false);
}

fn main() -> JsResult<()> {
    let mut args: Vec<String> = env::args().collect();
    match args.last() {
        Some(last_arg) => {
            if last_arg == "debug" {
                let mut debug = DEBUG.lock().unwrap();
                *debug = true;
                args.pop();
            }
        }
        _ => (),
    }

    match args.len() < 2 {
        true => {
            print_c(colors::RED, styles:: BOLD, "[V12]: Error: Usage: V12 <script_path>.ts/.js, version [debug]\n");
            return if *DEBUG.lock().unwrap() {
                Ok(on_de_initialize())
            } else {
                Ok(())
            }
        }
        false => (),
    }

    let arg1: &String = &args[1];

    match arg1.as_str() {
        arg if arg.ends_with(".ts") => {
            process_file(arg);
        }
        arg if arg.ends_with(".js") => {
            let engine: Engine = Engine::new();
            engine.run();
            if *DEBUG.lock().unwrap() {
                log("Engine has started successfully.\n");
            }
            engine.begin(arg)?;
        }
        "version" => {
            show_about()?;
        }
        _ => {
            print_c(colors::RED, styles:: BOLD, "[V12]: Error: Usage: V12 <script_path>.ts/.js, version [debug]\n");
        }
    }

    Ok(())
}

fn show_about() -> JsResult<()> {
    let engine = Engine::new();
    engine.run();
    utils::about_v12::about_v12();
    if *DEBUG.lock().unwrap() {
        Ok(on_de_initialize())
    } else {
        Ok(())
    }
}