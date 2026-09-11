pub mod cli;
pub mod options;

use crate::config::{AppConfig, Config};
use anyhow::{Context, Result};
use std::path::Path;
use tracing::info;

pub async fn patch(
    cfg: &Config,
    id: &str,
    app: &AppConfig,
    apk_path: &str,
    output_dir: &str,
) -> Result<String> {
    ensure_keystore(id, app).await?;

    let repo = cfg.patch_sources.get(&app.patch_source)
        .map(|p| p.repo.clone())
        .unwrap_or_else(|| app.patch_source.clone());

    let output_apk = format!("{output_dir}/{id}-patched.apk");
    let args = cli::build_args(&cfg.build.tools_dir, &repo, app, apk_path, &output_apk);

    let mut cmd = tokio::process::Command::new("java");
    cmd.args(["-jar", &args.cli_jar, "patch"])
        .arg(format!("--patches={}", args.patches_arg))
        .arg("-f")
        .arg("--continue-on-error")
        .arg("-o")
        .arg(&args.output_apk);

    if !args.included.is_empty() {
        cmd.arg("--exclusive");
    }

    if let Some((file, alias, pass)) = &args.keystore {
        cmd.arg(format!("--keystore={file}"))
            .arg(format!("--keystore-entry-alias={alias}"))
            .arg(format!("--keystore-password={pass}"))
            .arg(format!("--keystore-entry-password={pass}"));
    }

    for patch in &args.included {
        cmd.args(["-e", patch]);
    }
    for patch in &args.excluded {
        cmd.args(["-d", patch]);
    }
    for raw in &args.raw_args {
        cmd.arg(raw);
    }

    cmd.arg(&args.input_apk);

    info!("{id}: patching with morphe-cli...");
    let status = cmd.status().await.context("java not found — install JDK 21+")?;
    if !status.success() {
        anyhow::bail!("{id}: morphe-cli exited with {status}");
    }

    info!("{id}: patched → {output_apk}");
    Ok(output_apk)
}

async fn ensure_keystore(id: &str, app: &AppConfig) -> Result<()> {
    if let Some(ks) = &app.keystore {
        if Path::new(&ks.file).exists() {
            return Ok(());
        }
        crate::utils::gen_keystore(id, app).await?;
    }
    Ok(())
}
