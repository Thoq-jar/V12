use crate::{
  DEBUG,
  engine::engine::Engine,
  utils::helper::path
};
use std::{
  fs,
  path::PathBuf,
  process::exit
};
use super::logutil::log;
use regex::Regex;

pub fn strip_types(ts_file_path: &str) -> String {
  let full_path: PathBuf = path(ts_file_path);
  let ts_content: String = match fs::read_to_string(&full_path) {
    Ok(content) => content,
    Err(_) => {
      eprintln!("[V12]: Unable to read TypeScript file: {:?}", full_path.display());
      exit(1);
    }
  };

  let re: Regex = Regex::new(r":\s*\w+(\[])?|<\w+>").unwrap();
  let js_content: String = re.replace_all(&ts_content, "").to_string();
  let temp_file_path: String = format!("{}.js", ts_file_path);
  fs::write(&temp_file_path, js_content).expect(&format!(
    "[V12]: Unable to write JavaScript file: {:?}",
    temp_file_path
  ));
  temp_file_path
}

pub fn process_file(ts_file_path: &str) {
  let temp_file_path: String = strip_types(ts_file_path);
  let engine = Engine::new();
  engine.run();
  match *DEBUG.lock().unwrap() {
    true => {
        log("Engine has started successfully.\n");
      }
    false => (),
}
  engine.begin(&temp_file_path).expect(&format!(
    "[V12]: Failed to execute TypeScript file: {}",
    temp_file_path
  ));
  fs::remove_file(temp_file_path.clone()).expect(&format!(
    "[V12]: Unable to delete generated JavaScript file: {}",
    temp_file_path
  ));
}