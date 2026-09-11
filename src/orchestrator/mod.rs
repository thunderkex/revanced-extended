pub mod discovery;
pub mod resolver;
pub mod scheduler;

use crate::config::Config;
use crate::utils;
use anyhow::Result;
use tracing::info;

pub async fn list_apps(cfg: &Config, json: bool) -> Result<()> {
    if json {
        let list: Vec<_> = cfg.apps.iter().map(|(id, a)| {
            serde_json::json!({
                "id": id,
                "enabled": a.enabled,
                "package": a.package,
                "patch_source": a.patch_source,
                "mode": a.mode,
                "architectures": a.architectures,
                "description": a.description
            })
        }).collect();
        println!("{}", serde_json::to_string_pretty(&list)?);
    } else {
        for (id, app) in &cfg.apps {
            println!("{:24} enabled={:5} pkg={}", id, app.enabled, app.package);
        }
    }
    Ok(())
}

pub async fn build_apps(
    cfg: &Config,
    apps_input: &str,
    arch: &str,
    _mode: &str,
    output_dir: &str,
    _force: bool,
) -> Result<Vec<String>> {
    std::fs::create_dir_all(output_dir)?;
    std::fs::create_dir_all(&cfg.build.temp_dir)?;
    std::fs::create_dir_all(&cfg.build.tools_dir)?;
    std::fs::create_dir_all(&cfg.build.keys_dir)?;

    utils::download_tools(cfg).await?;

    let targets = resolver::resolve_targets(cfg, apps_input)?;
    info!("Starting build pipeline for {} targets: {:?}", targets.len(), targets);

    let built = scheduler::run_pipeline(cfg, &targets, arch, output_dir).await?;
    info!("Build complete. {} APKs produced.", built.len());
    Ok(built)
}

pub async fn check_updates(cfg: &Config, json: bool) -> Result<()> {
    discovery::check_updates(cfg, json).await
}

pub async fn generate_matrix(cfg: &Config, apps_input: &str, arch: &str, mode: &str) -> Result<()> {
    let targets = resolver::resolve_targets(cfg, apps_input)?;
    let archs: Vec<&str> = if arch == "all" {
        vec!["arm64-v8a", "armeabi-v7a", "x86_64"]
    } else {
        vec![arch]
    };

    let mut entries = Vec::new();
    for app in targets {
        for a in &archs {
            entries.push(serde_json::json!({
                "app": app,
                "arch": a,
                "mode": mode,
            }));
        }
    }

    let matrix = serde_json::json!({ "include": entries });
    println!("{}", serde_json::to_string(&matrix)?);
    Ok(())
}
