pub mod arch;
pub mod lite;
pub mod signer;

use crate::config::{AppConfig, Config};
use anyhow::{Context, Result};
use regex::Regex;
use reqwest::header::{HeaderMap, HeaderValue, USER_AGENT};
use reqwest::Client;
use std::path::Path;
use tracing::{info, warn};

const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

fn make_client() -> Result<Client> {
    let mut headers = HeaderMap::new();
    headers.insert(USER_AGENT, HeaderValue::from_static(UA));
    Client::builder()
        .default_headers(headers)
        .redirect(reqwest::redirect::Policy::limited(10))
        .timeout(std::time::Duration::from_secs(180))
        .build()
        .map_err(Into::into)
}

pub async fn fetch_apk(cfg: &Config, id: &str, app: &AppConfig, arch: &str) -> Result<String> {
    let dest = format!("{}/{id}-input.apk", cfg.build.temp_dir);
    if Path::new(&dest).exists() && std::fs::metadata(&dest)?.len() > 1_000_000 {
        info!("{id}: cached input APK exists at {dest}");
        return Ok(dest);
    }

    let client = make_client()?;

    if let Some(url) = &app.apk_url {
        let final_url = if url.contains("github.com") && url.contains("/releases/") {
            resolve_github_asset_url(&client, url, arch).await.unwrap_or_else(|_| url.clone())
        } else {
            url.clone()
        };
        info!("{id}: downloading from direct apk_url {final_url}");
        match download_and_extract_if_bundle(&client, &final_url, &dest).await {
            Ok(_) => return Ok(dest),
            Err(e) => warn!("{id}: direct apk_url failed: {e}"),
        }
    }

    if let Some(url) = &app.archive_url {
        info!("{id}: checking archive.org source {url}");
        match fetch_archive_org(&client, url, arch, &dest).await {
            Ok(path) => return Ok(path),
            Err(e) => warn!("{id}: archive.org failed: {e}"),
        }
    }

    if let Some(url) = &app.apkmirror_url {
        info!("{id}: checking apkmirror source {url}");
        match fetch_apkmirror(&client, url, arch, &dest).await {
            Ok(path) => return Ok(path),
            Err(e) => warn!("{id}: apkmirror failed: {e}"),
        }
    }

    if let Some(url) = &app.uptodown_url {
        info!("{id}: checking uptodown source {url}");
        match fetch_uptodown(&client, url, arch, &dest).await {
            Ok(path) => return Ok(path),
            Err(e) => warn!("{id}: uptodown failed: {e}"),
        }
    }

    if !app.package.is_empty() {
        info!("{id}: trying apkpure fallback for package {}", app.package);
        match fetch_apkpure(&client, &app.package, &dest).await {
            Ok(path) => return Ok(path),
            Err(e) => warn!("{id}: apkpure failed: {e}"),
        }

        info!("{id}: trying apkeep fallback for package {}", app.package);
        match fetch_apkeep(&app.package, &dest).await {
            Ok(path) => return Ok(path),
            Err(e) => warn!("{id}: apkeep failed: {e}"),
        }
    }

    anyhow::bail!("{id}: all download sources exhausted for package '{}'", app.package);
}

async fn fetch_archive_org(client: &Client, url: &str, arch: &str, dest: &str) -> Result<String> {
    let base = if url.ends_with('/') {
        url.to_string()
    } else {
        format!("{url}/")
    };

    info!("archive.org: listing files from {base}");
    let html = client.get(&base).send().await?.text().await?;

    let re = Regex::new(r#"href="([^"]+\.(?:apk|apkm))""#)?;
    let mut candidates: Vec<String> = Vec::new();

    for cap in re.captures_iter(&html) {
        let file = &cap[1];
        if file.contains('/') || file.starts_with('?') || file.contains('~') {
            continue;
        }
        candidates.push(file.to_string());
    }

    if candidates.is_empty() {
        anyhow::bail!("No APK/APKM found in archive.org directory {base}");
    }

    let chosen = candidates
        .iter()
        .rfind(|f| f.contains(arch))
        .or_else(|| candidates.iter().rfind(|f| f.contains("-all.") || f.contains("_all.")))
        .or_else(|| candidates.iter().rfind(|f| f.contains("universal")))
        .or_else(|| candidates.last())
        .ok_or_else(|| anyhow::anyhow!("No matching file candidate"))?;

    let download_url = format!("{base}{chosen}");
    info!("archive.org: downloading {download_url}");
    download_and_extract_if_bundle(client, &download_url, dest).await?;
    Ok(dest.to_string())
}

async fn fetch_apkmirror(client: &Client, app_url: &str, arch: &str, dest: &str) -> Result<String> {
    info!("apkmirror: loading app page {app_url}");
    let base_origin = "https://www.apkmirror.com";
    let app_html = client.get(app_url).send().await?.text().await?;

    let re_rel = Regex::new(r#"href="(/apk/[^"]+-release/)""#)?;
    let release_path = re_rel
        .captures(&app_html)
        .map(|c| c[1].to_string())
        .ok_or_else(|| anyhow::anyhow!("No release links found on {app_url}"))?;

    let release_url = format!("{base_origin}{release_path}");
    info!("apkmirror: loading release {release_url}");
    let rel_html = client.get(&release_url).send().await?.text().await?;

    let re_var = Regex::new(r#"href="(/apk/[^"]+-android-apk-download/)""#)?;
    let mut variants: Vec<String> = Vec::new();
    for cap in re_var.captures_iter(&rel_html) {
        variants.push(cap[1].to_string());
    }
    if variants.is_empty() {
        anyhow::bail!("No variant links found on {release_url}");
    }

    let variant_path = variants
        .iter()
        .find(|v| v.contains(arch))
        .or_else(|| variants.first())
        .unwrap();

    let variant_url = format!("{base_origin}{variant_path}");
    info!("apkmirror: loading variant {variant_url}");
    let var_html = client.get(&variant_url).send().await?.text().await?;

    let re_dl = Regex::new(r#"href="(/apk/[^"]+/download/\?key=[^"]+)""#)?;
    let dl_path = re_dl
        .captures(&var_html)
        .map(|c| c[1].to_string())
        .ok_or_else(|| anyhow::anyhow!("No intermediate download button found on {variant_url}"))?;

    let dl_url = format!("{base_origin}{dl_path}");
    info!("apkmirror: loading download landing page {dl_url}");
    let dl_html = client.get(&dl_url).send().await?.text().await?;

    let re_php = Regex::new(r#"href="(/wp-content/themes/APKMirror/download\.php\?[^"]+)""#)?;
    let php_path = re_php
        .captures(&dl_html)
        .map(|c| c[1].to_string())
        .ok_or_else(|| anyhow::anyhow!("No download.php link found on {dl_url}"))?;

    let php_url = format!("{base_origin}{php_path}");
    info!("apkmirror: resolving direct CDN location from {php_url}");

    let mut hdrs = HeaderMap::new();
    hdrs.insert(USER_AGENT, HeaderValue::from_static(UA));
    let no_redir_client = Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .default_headers(hdrs)
        .build()?;

    let res = no_redir_client
        .get(&php_url)
        .header("Referer", &dl_url)
        .send()
        .await?;

    let cdn_url = if let Some(loc) = res.headers().get("location") {
        loc.to_str()?.to_string()
    } else {
        php_url
    };

    info!("apkmirror: downloading from CDN {cdn_url}");
    download_and_extract_if_bundle(client, &cdn_url, dest).await?;
    Ok(dest.to_string())
}

async fn fetch_uptodown(client: &Client, base_url: &str, _arch: &str, dest: &str) -> Result<String> {
    let versions_url = format!("{base_url}/versions");
    info!("uptodown: checking versions at {versions_url}");
    let html = client.get(&versions_url).send().await?.text().await?;

    let re_code = Regex::new(r#"id="detail-app-name"[^>]*data-code="([0-9]+)""#)?;
    let data_code = re_code
        .captures(&html)
        .map(|c| c[1].to_string())
        .ok_or_else(|| anyhow::anyhow!("Could not find data-code on {versions_url}"))?;

    let api_url = format!("{base_url}/apps/{data_code}/versions/1");
    info!("uptodown: querying version api {api_url}");

    let res = client
        .get(&api_url)
        .header("X-Requested-With", "XMLHttpRequest")
        .send()
        .await?;

    let json: serde_json::Value = res.json().await?;
    let data = json["data"]
        .as_array()
        .ok_or_else(|| anyhow::anyhow!("Unexpected JSON structure from uptodown versions API"))?;

    if data.is_empty() {
        anyhow::bail!("No versions returned by uptodown API");
    }

    let first = &data[0];
    let file_id = first["fileID"].as_i64().unwrap_or(0);
    info!("uptodown: latest version fileID: {file_id}");

    let dl_page = format!("{base_url}/download/{file_id}-x");
    let dl_html = client.get(&dl_page).send().await?.text().await?;

    let re_dwn = Regex::new(r#"data-url="([^"]+)""#)?;
    if let Some(cap) = re_dwn.captures(&dl_html) {
        let token = &cap[1];
        if !token.starts_with("http") && token.len() > 10 {
            let direct = format!("https://dw.uptodown.com/dwn/{token}");
            info!("uptodown: downloading from direct token {direct}");
            if download_and_extract_if_bundle(client, &direct, dest).await.is_ok() {
                return Ok(dest.to_string());
            }
        }
    }

    anyhow::bail!("Uptodown direct download requires Turnstile response; fallback to another source");
}

async fn resolve_github_asset_url(client: &Client, url: &str, arch: &str) -> Result<String> {
    let re = Regex::new(r#"github\.com/([^/]+)/([^/]+)/releases"#)?;
    if let Some(cap) = re.captures(url) {
        let owner = &cap[1];
        let repo = &cap[2];
        let api_url = format!("https://api.github.com/repos/{owner}/{repo}/releases/latest");
        let token = std::env::var("GITHUB_TOKEN").unwrap_or_default();
        let mut req = client.get(&api_url);
        if !token.is_empty() {
            req = req.bearer_auth(&token);
        }
        let release: serde_json::Value = req.send().await?.json().await?;
        if let Some(assets) = release["assets"].as_array() {
            let mut candidates: Vec<String> = Vec::new();
            for asset in assets {
                let name = asset["name"].as_str().unwrap_or("");
                if name.ends_with(".apk") && !name.contains("hw-") {
                    if let Some(dl) = asset["browser_download_url"].as_str() {
                        candidates.push(dl.to_string());
                    }
                }
            }
            if let Some(dl) = candidates.iter().find(|u| u.contains(arch)) {
                return Ok(dl.clone());
            }
            if let Some(dl) = candidates.iter().find(|u| u.contains("all") || u.contains("universal")) {
                return Ok(dl.clone());
            }
            if let Some(dl) = candidates.first() {
                return Ok(dl.clone());
            }
        }
    }
    Ok(url.to_string())
}

async fn fetch_apkeep(package: &str, dest: &str) -> Result<String> {
    let tmp_dir = tempfile::tempdir()?;
    let out_dir = tmp_dir.path().to_str().unwrap();

    let status = tokio::process::Command::new("apkeep")
        .args(["-a", package, "-d", "apk-pure", out_dir])
        .status()
        .await
        .context("Running apkeep")?;

    if !status.success() {
        anyhow::bail!("apkeep exited with status {status}");
    }

    for entry in std::fs::read_dir(out_dir)? {
        let entry = entry?;
        let p = entry.path();
        if p.extension().and_then(|e| e.to_str()) == Some("apk") {
            std::fs::copy(&p, dest)?;
            return Ok(dest.to_string());
        }
    }

    anyhow::bail!("apkeep finished but produced no .apk in {out_dir}")
}

pub async fn download_and_extract_if_bundle(
    client: &Client,
    url: &str,
    dest_apk_path: &str,
) -> Result<()> {
    if let Some(parent) = Path::new(dest_apk_path).parent() {
        std::fs::create_dir_all(parent)?;
    }

    let temp_dl = format!("{dest_apk_path}.tmp");
    crate::utils::download_file_with_client(client, url, &temp_dl, 3).await?;

    if is_zip_file(&temp_dl) {
        info!("Checking if downloaded file is a ZIP bundle (.apkm/.xapk/split) or APK...");
        if let Ok(_) = extract_base_apk_from_zip(&temp_dl, dest_apk_path) {
            let _ = std::fs::remove_file(&temp_dl);
            return Ok(());
        }
    }

    std::fs::rename(&temp_dl, dest_apk_path)?;
    Ok(())
}

async fn fetch_apkpure(client: &Client, package: &str, dest: &str) -> Result<String> {
    info!("apkpure: trying direct download for package {package}");
    let urls = [
        format!("https://d.apkpure.net/b/APK/{package}?version=latest"),
        format!("https://d.apkpure.net/b/XAPK/{package}?version=latest"),
    ];

    for url in &urls {
        info!("apkpure: attempting {url}");
        if let Ok(_) = download_and_extract_if_bundle(client, url, dest).await {
            if Path::new(dest).exists() && std::fs::metadata(dest)?.len() > 1_000_000 {
                info!("apkpure: successfully downloaded {package} to {dest}");
                return Ok(dest.to_string());
            }
        }
    }
    anyhow::bail!("APKPure download failed for {package}")
}

fn is_zip_file(path: &str) -> bool {
    if let Ok(mut file) = std::fs::File::open(path) {
        use std::io::Read;
        let mut magic = [0u8; 4];
        if file.read_exact(&mut magic).is_ok() {
            return magic == [0x50, 0x4B, 0x03, 0x04];
        }
    }
    false
}

fn extract_base_apk_from_zip(zip_path: &str, dest: &str) -> Result<()> {
    let file = std::fs::File::open(zip_path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    let mut best_index: Option<usize> = None;
    let mut max_size: u64 = 0;

    for i in 0..archive.len() {
        let item = archive.by_index(i)?;
        let name = item.name().to_lowercase();
        if name.ends_with(".apk") {
            if name.ends_with("base.apk") {
                best_index = Some(i);
                break;
            }
            if item.size() > max_size {
                max_size = item.size();
                best_index = Some(i);
            }
        }
    }

    let idx = best_index.ok_or_else(|| anyhow::anyhow!("No .apk found inside ZIP bundle"))?;
    let mut entry = archive.by_index(idx)?;
    let mut out = std::fs::File::create(dest)?;
    std::io::copy(&mut entry, &mut out)?;

    info!("Extracted {} bytes to {dest}", entry.size());
    Ok(())
}
