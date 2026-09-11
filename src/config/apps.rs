use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct AppConfig {
    pub enabled: bool,
    #[serde(default)]
    pub package: String,
    #[serde(alias = "patches-source", default)]
    pub patch_source: String,
    #[serde(alias = "patch-branch", alias = "branch", default)]
    pub patch_branch: Option<String>,
    #[serde(alias = "cli-source", default = "default_cli")]
    pub cli_source: String,
    #[serde(alias = "uptodown-dlurl", default)]
    pub uptodown_url: Option<String>,
    #[serde(alias = "apkmirror-dlurl", default)]
    pub apkmirror_url: Option<String>,
    #[serde(alias = "archive-dlurl", default)]
    pub archive_url: Option<String>,
    #[serde(alias = "apk_source", default)]
    pub apk_source: String,
    #[serde(alias = "apk_url", default)]
    pub apk_url: Option<String>,
    #[serde(alias = "arch", default = "default_arch")]
    pub architectures: Vec<String>,
    #[serde(alias = "build-mode", default = "default_mode")]
    pub mode: String,
    #[serde(alias = "included-patches", default)]
    pub included_patches: Vec<String>,
    #[serde(alias = "excluded-patches", default)]
    pub excluded_patches: Vec<String>,
    #[serde(alias = "patcher-args", default)]
    pub patcher_args: Option<String>,
    #[serde(alias = "patches-version", default)]
    pub patches_version: Option<String>,
    #[serde(default)]
    pub patches: Vec<String>,
    #[serde(default)]
    pub keystore: Option<KeystoreRef>,
    #[serde(default)]
    pub module: Option<ModuleFlags>,
    #[serde(default)]
    pub dependencies: Vec<String>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub min_version: Option<String>,
    #[serde(default)]
    pub max_version: Option<String>,
}

fn default_cli() -> String { "MorpheApp/morphe-desktop".to_string() }
fn default_arch() -> Vec<String> { vec!["arm64-v8a".to_string()] }
fn default_mode() -> String { "full".to_string() }

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct KeystoreRef {
    #[serde(default = "default_alias")]
    pub alias: String,
    #[serde(default = "default_keystore_file")]
    pub file: String,
}

fn default_alias() -> String { "revanced".to_string() }
fn default_keystore_file() -> String { "keys/default.jks".to_string() }

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ModuleFlags {
    #[serde(default = "default_true")]
    pub single: bool,
    #[serde(default = "default_true")]
    pub bundle: bool,
}

fn default_true() -> bool { true }
