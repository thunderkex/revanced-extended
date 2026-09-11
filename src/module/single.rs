use crate::config::Config;
use anyhow::Result;
use tracing::info;

pub async fn build_single_module(cfg: &Config, app_id: &str, output_dir: &str) -> Result<()> {
    if app_id.eq_ignore_ascii_case("microg") {
        anyhow::bail!("MicroG is not needed in root module mode.");
    }
    std::fs::create_dir_all(output_dir)?;
    info!("Building single module for {app_id} in {output_dir}...");

    let search_dirs = [output_dir, "output", &cfg.build.output_dir];
    let mut found = Vec::new();

    for dir in &search_dirs {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                    if (name.starts_with(app_id) || name.contains(app_id)) && name.ends_with(".apk") {
                        found.push(p.to_string_lossy().to_string());
                        break;
                    }
                }
            }
        }
        if !found.is_empty() {
            break;
        }
    }

    if found.is_empty() {
        anyhow::bail!("No APK found for app '{app_id}' across output directories");
    }

    let mod_id = format!("revancex-{app_id}");
    let clean_name = app_id
        .replace('_', " ")
        .replace("youtube", "YouTube")
        .replace("microg", "MicroG");
    let mod_name = format!("ReVanceX - {clean_name}");
    let zip_name = format!("revancex-module-{app_id}.zip");

    super::bundle::build_custom_module(
        cfg,
        &found.join(","),
        false,
        output_dir,
        Some(&mod_id),
        Some(&mod_name),
        Some(&zip_name),
    ).await
}
