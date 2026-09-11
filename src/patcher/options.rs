use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PatchOption {
    pub key: String,
    pub value: serde_json::Value,
}

pub fn serialize_options(options: &[PatchOption]) -> Option<String> {
    if options.is_empty() {
        None
    } else {
        serde_json::to_string(options).ok()
    }
}
