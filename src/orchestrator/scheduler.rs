use crate::builder;
use crate::config::{AppConfig, Config};
use crate::patcher;
use anyhow::Result;
use futures::future::join_all;
use std::sync::Arc;
use tokio::sync::Semaphore;
use tracing::{info, warn};

pub async fn run_pipeline(
    cfg: &Config,
    targets: &[String],
    arch: &str,
    output_dir: &str,
) -> Result<Vec<String>> {
    let semaphore = Arc::new(Semaphore::new(cfg.build.workers));
    let mut handles = Vec::new();

    for id in targets {
        if let Some(app) = cfg.apps.get(id) {
            let id = id.clone();
            let app = app.clone();
            let cfg = cfg.clone();
            let arch = arch.to_string();
            let output_dir = output_dir.to_string();
            let sem = semaphore.clone();

            handles.push(tokio::spawn(async move {
                let _permit = sem.acquire().await.unwrap();
                build_single(&cfg, &id, &app, &arch, &output_dir).await
            }));
        }
    }

    let results = join_all(handles).await;
    let mut built = Vec::new();
    for res in results {
        match res {
            Ok(Ok(path)) => built.push(path),
            Ok(Err(e)) => warn!("Build failed: {e}"),
            Err(e) => warn!("Task panicked: {e}"),
        }
    }

    Ok(built)
}

async fn build_single(
    cfg: &Config,
    id: &str,
    app: &AppConfig,
    arch: &str,
    output_dir: &str,
) -> Result<String> {
    info!("Processing {id} (mode={}, patch_source={})...", app.mode, app.patch_source);

    let apk_path = builder::fetch_apk(cfg, id, app, arch).await?;

    if app.mode == "install" || app.patch_source == "none" || app.patch_source.is_empty() {
        let dest = format!("{output_dir}/{id}.apk");
        std::fs::copy(&apk_path, &dest)?;
        info!("{id}: copied unpatched official APK to {dest}");
        return Ok(dest);
    }

    if arch != "all" {
        if let Err(e) = builder::arch::strip_unsupported_archs(&apk_path, arch) {
            warn!("{id}: arch stripping note: {e}");
        }
    }

    if app.mode == "lite" {
        if let Err(e) = builder::lite::optimize_apk(&apk_path) {
            warn!("{id}: lite optimization note: {e}");
        }
    }

    let patched = patcher::patch(cfg, id, app, &apk_path, output_dir).await?;

    if app.mode == "lite" {
        let _ = builder::lite::optimize_apk(&patched);
    }

    Ok(patched)
}
