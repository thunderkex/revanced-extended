use crate::config::Config;
use anyhow::{Context, Result};
use std::io::Write;
use std::path::Path;
use tracing::info;
use zip::write::SimpleFileOptions;

#[derive(Debug, Clone)]
pub struct BundleCategory {
    pub id: &'static str,
    pub name: &'static str,
    pub filename: &'static str,
    pub apps: &'static [&'static str],
}

pub const BUNDLE_CATEGORIES: &[BundleCategory] = &[
    BundleCategory {
        id: "revancex-multimedia",
        name: "ReVanceX Multimedia Bundle",
        filename: "revancex-bundle-multimedia.zip",
        apps: &[
            "youtube",
            "youtube_music",
            "youtube_morphed",
            "youtube_music_morphed",
            "spotify",
            "soundcloud",
            "prime_video",
        ],
    },
    BundleCategory {
        id: "revancex-social",
        name: "ReVanceX Social Media Bundle",
        filename: "revancex-bundle-social.zip",
        apps: &[
            "reddit",
            "tiktok",
            "instagram",
            "facebook",
            "threads",
            "x_piko",
            "pixiv",
        ],
    },
    BundleCategory {
        id: "revancex-productivity",
        name: "ReVanceX Productivity Bundle",
        filename: "revancex-bundle-productivity.zip",
        apps: &[
            "wps_office",
            "camscanner",
            "solid_explorer",
            "fx_file_explorer",
            "rar",
            "google_photos",
            "lightroom",
            "google_recorder",
            "google_news",
            "terabox",
            "photomath",
        ],
    },
    BundleCategory {
        id: "revancex-tools",
        name: "ReVanceX Tools & Utilities Bundle",
        filename: "revancex-bundle-tools.zip",
        apps: &[
            "adguard",
            "brave_browser",
            "proton_vpn",
            "psiphon",
            "battery_guru",
            "smart_launcher",
            "nova_launcher",
            "tasker",
            "waze",
            "truecaller",
            "eyecon_caller",
            "zalo",
            "strava",
            "myfitnesspal",
        ],
    },
    BundleCategory {
        id: "revancex",
        name: "ReVanceX Core Bundle",
        filename: "revancex-bundle.zip",
        apps: &[
            "youtube",
            "youtube_music",
            "reddit",
            "spotify",
            "x_piko",
        ],
    },
];

pub async fn build_bundle_module(
    cfg: &Config,
    apps_or_paths: &str,
    include_webui: bool,
    output_dir: &str,
) -> Result<()> {
    let lower = apps_or_paths.to_lowercase().trim().to_string();
    if lower == "all" || lower == "all-enabled" || lower == "categories" {
        for cat in BUNDLE_CATEGORIES {
            let cat_apps = cat.apps.join(",");
            build_custom_module(
                cfg,
                &cat_apps,
                include_webui,
                output_dir,
                Some(cat.id),
                Some(cat.name),
                Some(cat.filename),
            )
            .await?;
        }
        Ok(())
    } else if let Some(cat) = BUNDLE_CATEGORIES.iter().find(|c| {
        let id_clean = c.id.trim_start_matches("revancex-");
        lower == id_clean
            || lower == c.id
            || (lower == "social_media" && id_clean == "social")
            || (lower == "media" && id_clean == "multimedia")
            || (lower == "utilities" && id_clean == "tools")
    }) {
        let cat_apps = cat.apps.join(",");
        build_custom_module(
            cfg,
            &cat_apps,
            include_webui,
            output_dir,
            Some(cat.id),
            Some(cat.name),
            Some(cat.filename),
        )
        .await
    } else {
        build_custom_module(cfg, apps_or_paths, include_webui, output_dir, None, None, None).await
    }
}

pub async fn build_custom_module(
    cfg: &Config,
    apps_or_paths: &str,
    include_webui: bool,
    output_dir: &str,
    module_id: Option<&str>,
    module_name: Option<&str>,
    zip_filename: Option<&str>,
) -> Result<()> {
    std::fs::create_dir_all(output_dir)?;

    let mut apks = Vec::new();
    let mut seen_names = std::collections::HashSet::new();
    let search_dirs = [output_dir, "output", &cfg.build.output_dir];

    for token in apps_or_paths.split(',').map(str::trim).filter(|s| !s.is_empty()) {
        if token.eq_ignore_ascii_case("microg") {
            continue;
        }
        let p = Path::new(token);
        if p.exists() && p.is_file() {
            if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                if !name.to_lowercase().contains("microg") && seen_names.insert(name.to_string()) {
                    apks.push(token.to_string());
                }
            }
        } else if token == "all" || token == "all-enabled" {
            for dir in &search_dirs {
                if let Ok(entries) = std::fs::read_dir(dir) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if path.extension().and_then(|e| e.to_str()) == Some("apk") {
                            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                                if !name.to_lowercase().contains("microg") && seen_names.insert(name.to_string()) {
                                    apks.push(path.to_string_lossy().to_string());
                                }
                            }
                        }
                    }
                }
            }
        } else {
            for dir in &search_dirs {
                if let Ok(entries) = std::fs::read_dir(dir) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                            let stem = name.trim_end_matches(".apk").trim_end_matches("-patched");
                            if (stem == token
                                || name.starts_with(&format!("{token}-"))
                                || name == format!("{token}.apk")
                                || name == format!("{token}-patched.apk"))
                                && name.ends_with(".apk")
                            {
                                if !name.to_lowercase().contains("microg") && seen_names.insert(name.to_string()) {
                                    apks.push(path.to_string_lossy().to_string());
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    const MAX_BUNDLE_BYTES: u64 = 1_800_000_000;
    let mut total_bundle_size: u64 = 0;
    let mut selected_apks = Vec::new();

    apks.sort_by(|a, b| {
        let priority = |p: &str| {
            let lower = p.to_lowercase();
            if lower.contains("youtube") { 0 }
            else if lower.contains("reddit") { 1 }
            else if lower.contains("spotify") { 2 }
            else if lower.contains("piko") || lower.contains("twitter") || lower.contains("x_") { 3 }
            else if lower.contains("photos") { 4 }
            else { 10 }
        };
        priority(a).cmp(&priority(b))
    });

    for apk in apks {
        let size = std::fs::metadata(&apk).map(|m| m.len()).unwrap_or(0);
        if total_bundle_size + size > MAX_BUNDLE_BYTES {
            tracing::warn!(
                "Bundle size limit (1.8 GiB) reached while adding '{}'. Skipping further APKs for this bundle.",
                apk
            );
            break;
        }
        total_bundle_size += size;
        selected_apks.push(apk);
    }
    let apks = selected_apks;

    if apks.is_empty() {
        tracing::warn!("No APKs found to bundle for '{apps_or_paths}' in '{output_dir}', skipping bundle creation.");
        return Ok(());
    }

    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();

    let mod_id = module_id.unwrap_or("revancex");
    let mod_name = module_name.unwrap_or("ReVanceX Bundle");
    let actual_zip_name = zip_filename.unwrap_or("revancex-bundle.zip");
    let zip_path = format!("{output_dir}/{actual_zip_name}");
    info!("Creating module '{mod_id}': {zip_path} with {} APKs", apks.len());

    let file = std::fs::File::create(&zip_path)?;
    let mut zip = zip::ZipWriter::new(file);
    let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

    zip.start_file("META-INF/com/google/android/update-binary", opts)?;
    zip.write_all(super::UPDATE_BINARY)?;

    zip.start_file("META-INF/com/google/android/updater-script", opts)?;
    zip.write_all(b"#MAGISK\n")?;

    let version = env!("CARGO_PKG_VERSION");
    zip.start_file("module.prop", opts)?;
    write!(
        zip,
        "id={mod_id}\nname={mod_name}\nversion=v{version}\nversionCode={ts}\nauthor=Thunderkex\ndescription=Patched module for {mod_name} via ReVanceX\n"
    )?;

    zip.start_file("customize.sh", opts)?;
    zip.write_all(super::CUSTOMIZE_SH)?;

    zip.start_file("utils.sh", opts)?;
    zip.write_all(super::UTILS_SH)?;

    zip.start_file("service.sh", opts)?;
    zip.write_all(super::SERVICE_SH)?;

    zip.start_file("action.sh", opts)?;
    zip.write_all(super::ACTION_SH)?;

    zip.start_file("uninstall.sh", opts)?;
    zip.write_all(super::UNINSTALL_SH)?;

    let mut apps_list_content = String::new();
    let mut apps_json_array = Vec::new();

    for apk in &apks {
        let file_stem = Path::new(apk)
            .file_stem()
            .and_then(|n| n.to_str())
            .unwrap_or("app");
        let app_id = file_stem.trim_end_matches("-patched");

        let (pkg, mode, desc) = if let Some(app_cfg) = cfg.apps.get(app_id) {
            (app_cfg.package.clone(), app_cfg.mode.clone(), app_cfg.description.clone())
        } else {
            (app_id.to_string(), "patch".to_string(), None)
        };

        apps_list_content.push_str(&format!("{app_id}:{pkg}:{mode}\n"));

        let clean_name = app_id
            .replace('_', " ")
            .replace("youtube", "YouTube")
            .replace("microg", "MicroG");

        apps_json_array.push(serde_json::json!({
            "id": app_id,
            "name": clean_name,
            "package": pkg,
            "mode": mode,
            "description": desc
        }));
    }

    zip.start_file("apps.list", opts)?;
    zip.write_all(apps_list_content.as_bytes())?;

    if include_webui {
        let json_str = serde_json::to_string_pretty(&apps_json_array).ok();
        super::webui::inject_webui(&mut zip, opts, json_str.as_deref())?;
    }

    for apk in &apks {
        let name = Path::new(apk)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("app.apk");
        let app_dir = name.trim_end_matches(".apk").trim_end_matches("-patched");

        let mut apk_file = std::fs::File::open(apk).with_context(|| format!("Opening {apk}"))?;
        let apk_entry = format!("apks/{app_dir}.apk");
        zip.start_file(&apk_entry, opts)?;
        std::io::copy(&mut apk_file, &mut zip)?;
    }

    zip.finish()?;
    info!("Bundle complete: {zip_path}");

    super::verify_bundle(&zip_path)?;
    Ok(())
}
