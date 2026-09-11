use crate::config::apps::AppConfig;
use crate::config::patches::PatchSourceEntry;
use crate::config::sources::{ApkSourceEntry, CliSource};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct BuildConfig {
    #[serde(default = "default_java")]
    pub java_min_version: u32,
    #[serde(default = "default_tools")]
    pub tools_dir: String,
    #[serde(default = "default_output")]
    pub output_dir: String,
    #[serde(default = "default_keys")]
    pub keys_dir: String,
    #[serde(default = "default_temp")]
    pub temp_dir: String,
    #[serde(default = "default_workers")]
    pub workers: usize,
    #[serde(default = "default_retries")]
    pub download_retries: u32,
    #[serde(default = "default_timeout")]
    pub download_timeout_secs: u64,
    #[serde(default = "default_cache")]
    pub version_cache: String,
}

fn default_java() -> u32 { 21 }
fn default_tools() -> String { "./tools".to_string() }
fn default_output() -> String { "./output".to_string() }
fn default_keys() -> String { "./keys".to_string() }
fn default_temp() -> String { "./tmp".to_string() }
fn default_workers() -> usize { 4 }
fn default_retries() -> u32 { 3 }
fn default_timeout() -> u64 { 180 }
fn default_cache() -> String { "./tmp/version_cache.json".to_string() }

#[derive(Debug, Clone)]
pub struct Config {
    pub apps: HashMap<String, AppConfig>,
    pub cli_repo: String,
    pub cli_pattern: String,
    pub patch_sources: HashMap<String, PatchSourceEntry>,
    pub apk_sources: HashMap<String, ApkSourceEntry>,
    pub build: BuildConfig,
}

#[derive(Debug, Deserialize, Serialize)]
struct AppsFile {
    apps: HashMap<String, AppConfig>,
}

#[derive(Debug, Deserialize, Serialize)]
struct SourcesFile {
    #[serde(default)]
    cli: Option<CliSource>,
    #[serde(default)]
    patch_sources: HashMap<String, PatchSourceEntry>,
    #[serde(default)]
    apk_sources: HashMap<String, ApkSourceEntry>,
}

#[derive(Debug, Deserialize, Serialize)]
struct BuildFile {
    build: BuildConfig,
}

pub fn load_config(config_dir: &str) -> Result<Config> {
    let read = |name: &str| -> Result<String> {
        let path = format!("{config_dir}/{name}");
        std::fs::read_to_string(&path).with_context(|| format!("Reading {path}"))
    };

    let apps: AppsFile = serde_yaml::from_str(&read("apps.yaml")?)?;
    let sources: SourcesFile = serde_yaml::from_str(&read("sources.yaml")?)?;
    let build_file: BuildFile = serde_yaml::from_str(&read("build.yaml")?)?;

    let (cli_repo, cli_pattern) = match sources.cli {
        Some(c) => (c.repo, c.asset_pattern),
        None => ("MorpheApp/morphe-desktop".to_string(), "morphe-*-all.jar".to_string()),
    };

    Ok(Config {
        apps: apps.apps,
        cli_repo,
        cli_pattern,
        patch_sources: sources.patch_sources,
        apk_sources: sources.apk_sources,
        build: build_file.build,
    })
}

pub fn validate_config(cfg: &Config, strict: bool) -> Result<()> {
    for (id, app) in &cfg.apps {
        for dep in &app.dependencies {
            if !cfg.apps.contains_key(dep) {
                anyhow::bail!("App '{id}' has unknown dependency '{dep}'");
            }
        }
        if strict && app.enabled && app.package.is_empty() {
            anyhow::bail!("App '{id}' is enabled but has no package defined");
        }
    }
    println!("Config valid. Total apps configured: {}", cfg.apps.len());
    Ok(())
}
