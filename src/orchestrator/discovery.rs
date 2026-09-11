use crate::config::Config;
use anyhow::Result;
use tracing::info;

pub async fn check_updates(cfg: &Config, json_output: bool) -> Result<()> {
    let mut changed_sources = Vec::new();
    let mut changed_apps = Vec::new();
    let client = reqwest::Client::builder()
        .user_agent("revancex/666")
        .build()?;

    for (name, source) in &cfg.patch_sources {
        let app_branch = cfg.apps.values()
            .find(|a| &a.patch_source == name)
            .and_then(|a| a.patch_branch.as_deref());
        let branch = app_branch.or(source.branch.as_deref());

        if let Ok(rel) = crate::utils::github::get_latest_release(&client, &source.repo, branch).await {
            info!("Patch source {} latest tag: {}", name, rel.tag_name);
            changed_sources.push(name.clone());
            for (app_name, app) in &cfg.apps {
                if app.enabled && &app.patch_source == name {
                    if !changed_apps.contains(app_name) {
                        changed_apps.push(app_name.clone());
                    }
                }
            }
        }
    }

    let has_updates = !changed_apps.is_empty();

    if json_output {
        let out = serde_json::json!({
            "has_updates": has_updates,
            "changed_apps": changed_apps,
            "changed_sources": changed_sources
        });
        println!("{}", serde_json::to_string_pretty(&out)?);
    } else {
        println!("Checked updates. Active patch sources: {}, Affected apps: {}", changed_sources.len(), changed_apps.len());
    }

    Ok(())
}
