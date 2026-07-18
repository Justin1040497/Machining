use std::fs;
use std::path::PathBuf;

use framelean_runtime::{analyze_media_response_schema, recalculate_configuration_response_schema};

fn main() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../schemas");
    fs::create_dir_all(&root).expect("create schema directory");
    write(
        root.join("analyze-media-response-v1.schema.json"),
        &analyze_media_response_schema(),
    );
    write(
        root.join("recalculate-configuration-response-v1.schema.json"),
        &recalculate_configuration_response_schema(),
    );
}

fn write(path: PathBuf, schema: &schemars::Schema) {
    let json = serde_json::to_string_pretty(schema).expect("serialize schema");
    fs::write(path, format!("{json}\n")).expect("write schema");
}
