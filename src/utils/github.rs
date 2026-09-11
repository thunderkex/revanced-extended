use anyhow::{Context, Result};
use reqwest::Client;
use serde::Deserialize;

#[derive(Deserialize, Clone)]
pub struct GhRelease {
    pub tag_name: String,
    #[serde(default)]
    pub target_commitish: String,
    pub assets: Vec<GhAsset>,
}

#[derive(Deserialize, Clone)]
pub struct GhAsset {
    pub name: String,
    pub browser_download_url: String,
}

pub async fn get_latest_release(client: &Client, repo: &str, branch: Option<&str>) -> Result<GhRelease> {
    let token = std::env::var("GITHUB_TOKEN").unwrap_or_default();
    let url = format!("https://api.github.com/repos/{repo}/releases?per_page=10");
    let mut req = client.get(&url);
    if !token.is_empty() {
        req = req.bearer_auth(&token);
    }
    if let Ok(resp) = req.send().await {
        if let Ok(releases) = resp.json::<Vec<GhRelease>>().await {
            if let Some(target_b) = branch {
                if let Some(rel) = releases.iter().find(|r| {
                    r.target_commitish.eq_ignore_ascii_case(target_b) || r.tag_name.contains(target_b)
                }) {
                    return Ok(rel.clone());
                }
            }
            if let Some(first) = releases.into_iter().next() {
                return Ok(first);
            }
        }
    }

    let url_latest = format!("https://api.github.com/repos/{repo}/releases/latest");
    let mut req_latest = client.get(&url_latest);
    if !token.is_empty() {
        req_latest = req_latest.bearer_auth(&token);
    }
    let rel = req_latest.send().await?.error_for_status()?.json().await?;
    Ok(rel)
}

pub async fn resolve_asset_url(
    client: &Client,
    repo: &str,
    pattern: &str,
    branch: Option<&str>,
) -> Result<String> {
    let release = get_latest_release(client, repo, branch).await
        .with_context(|| format!("Fetching release for {repo}"))?;

    let prefix = pattern.split('*').next().unwrap_or("");
    let suffix = pattern.rsplit('*').next().unwrap_or("");

    release
        .assets
        .into_iter()
        .find(|a| a.name.starts_with(prefix) && a.name.ends_with(suffix))
        .map(|a| a.browser_download_url)
        .ok_or_else(|| anyhow::anyhow!("No asset matching '{pattern}' in {repo}"))
}
