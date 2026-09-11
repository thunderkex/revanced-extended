pub mod cache;
pub mod github;
pub mod semver;

use crate::config::{AppConfig, Config};
use anyhow::{Context, Result};
use reqwest::Client;
use std::path::Path;
use tracing::info;

pub async fn download_tools(cfg: &Config) -> Result<()> {
    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(cfg.build.download_timeout_secs))
        .user_agent("revanced-builder/0.1")
        .build()?;

    let cli_dest = format!("{}/morphe-cli.jar", cfg.build.tools_dir);
    if !Path::new(&cli_dest).exists() {
        let url = github::resolve_asset_url(&client, &cfg.cli_repo, &cfg.cli_pattern, None).await
            .with_context(|| format!("fetching CLI from {}", cfg.cli_repo))?;
        download_file_with_client(&client, &url, &cli_dest, cfg.build.download_retries).await?;
    }

    let signer_dest = format!("{}/uber-apk-signer.jar", cfg.build.tools_dir);
    if !Path::new(&signer_dest).exists() {
        if let Ok(url) = github::resolve_asset_url(&client, "patrickfav/uber-apk-signer", "*.jar", None).await {
            let _ = download_file_with_client(&client, &url, &signer_dest, cfg.build.download_retries).await;
        }
    }

    let mut repo_branches: std::collections::HashMap<String, Option<String>> = std::collections::HashMap::new();
    for app in cfg.apps.values() {
        if !app.patch_source.is_empty() && app.patch_source != "none" {
            let (repo, source_branch) = cfg.patch_sources.get(&app.patch_source)
                .map(|p| (p.repo.clone(), p.branch.clone()))
                .unwrap_or_else(|| (app.patch_source.clone(), None));

            let branch = app.patch_branch.clone().or(source_branch);
            repo_branches.entry(repo).or_insert(branch);
        }
    }

    for (repo, branch) in repo_branches {
        let safe_name = repo.replace('/', "_");
        let dest = format!("{}/patches_{safe_name}.mpp", cfg.build.tools_dir);
        if Path::new(&dest).exists() {
            info!("Patches exist, skipping: {dest}");
            continue;
        }
        match github::resolve_asset_url(&client, &repo, "*.mpp", branch.as_deref()).await {
            Ok(url) => {
                download_file_with_client(&client, &url, &dest, cfg.build.download_retries).await?;
            }
            Err(e) => {
                tracing::warn!("Could not download patches from {repo}: {e}");
            }
        }
    }

    Ok(())
}

pub const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

pub async fn download_file(url: &str, dest: &str, retries: u32) -> Result<String> {
    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(180))
        .user_agent(UA)
        .build()?;
    download_file_with_client(&client, url, dest, retries).await
}

pub async fn download_file_with_client(client: &Client, url: &str, dest: &str, retries: u32) -> Result<String> {
    if let Some(parent) = Path::new(dest).parent() {
        std::fs::create_dir_all(parent)?;
    }
    for attempt in 0..=retries {
        match try_download(client, url, dest).await {
            Ok(_) => return Ok(dest.to_string()),
            Err(e) if attempt < retries => {
                tracing::warn!("Download attempt {attempt} failed: {e}, retrying...");
                tokio::time::sleep(std::time::Duration::from_secs(2u64.pow(attempt))).await;
            }
            Err(e) => return Err(e),
        }
    }
    unreachable!()
}

async fn try_download(client: &Client, url: &str, dest: &str) -> Result<()> {
    let path = Path::new(dest);
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let filename = path.file_name().and_then(|n| n.to_str()).unwrap_or("download.tmp");

    let aria_res = tokio::process::Command::new("aria2c")
        .args([
            "-x", "16",
            "-s", "16",
            "-j", "16",
            "-k", "1M",
            "-U", UA,
            "--file-allocation=none",
            "--allow-overwrite=true",
            "--auto-file-renaming=false",
            "--summary-interval=0",
            "-d", dir.to_str().unwrap_or("."),
            "-o", filename,
            url,
        ])
        .status()
        .await;

    if let Ok(status) = aria_res {
        if status.success() && Path::new(dest).exists() && std::fs::metadata(dest)?.len() > 0 {
            info!("aria2 accelerated download complete: {dest}");
            return Ok(());
        }
    }

    use futures::StreamExt;
    info!("Downloading {url} → {dest}");
    let resp = client.get(url).send().await?.error_for_status()?;
    let mut stream = resp.bytes_stream();
    let mut file = std::fs::File::create(dest)?;
    while let Some(chunk) = stream.next().await {
        std::io::Write::write_all(&mut file, &chunk?)?;
    }
    Ok(())
}

pub fn get_keystore_password() -> String {
    let pass = std::env::var("KEYSTORE_PASSWORD").unwrap_or_else(|_| "revanced".to_string());
    if pass.len() < 6 {
        format!("{:0<6}", pass)
    } else {
        pass
    }
}

pub async fn gen_keystore(id: &str, app: &AppConfig) -> Result<()> {
    let ks = match &app.keystore {
        Some(k) => k,
        None => return Ok(()),
    };
    if Path::new(&ks.file).exists() {
        return Ok(());
    }
    if let Some(parent) = Path::new(&ks.file).parent() {
        std::fs::create_dir_all(parent)?;
    }
    let password = get_keystore_password();
    let status = tokio::process::Command::new("keytool")
        .args([
            "-genkeypair", "-noprompt",
            "-keystore", &ks.file,
            "-alias", &ks.alias,
            "-keyalg", "RSA",
            "-keysize", "4096",
            "-validity", "10000",
            "-storepass", &password,
            "-keypass", &password,
            "-dname", "CN=Revanced Extended, OU=Ministry of Silly Builds, O=Thunderkex, L=CyberSpace, ST=Somewhere Over The Galaxy, C=XX",
        ])
        .status()
        .await
        .context("keytool not found — install JDK 17+")?;
    if !status.success() {
        anyhow::bail!("{id}: keytool failed");
    }
    info!("{id}: keystore created at {}", ks.file);
    Ok(())
}
