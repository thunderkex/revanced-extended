use anyhow::{Context, Result};
use std::io::{Read, Write};
use tracing::info;
use zip::write::SimpleFileOptions;

pub const ANDROID_ABIS: &[&str] = &["arm64-v8a", "armeabi-v7a", "x86", "x86_64", "armeabi", "mips", "mips64"];

pub fn is_arch_supported(target_arch: &str, file_name: &str) -> bool {
    let lower = file_name.to_lowercase();
    if lower.contains(target_arch) {
        return true;
    }
    if lower.contains("universal") || lower.contains("all") || lower.contains("noarch") {
        return true;
    }
    false
}

pub fn strip_unsupported_archs(apk_path: &str, target_arch: &str) -> Result<u64> {
    let initial_size = std::fs::metadata(apk_path)?.len();
    let temp_out = format!("{apk_path}.arch_stripped.tmp");

    info!("Stripping native libs for arch '{target_arch}' from {apk_path}...");

    let src_file = std::fs::File::open(apk_path)
        .with_context(|| format!("Opening APK at {apk_path}"))?;
    let mut zip_in = zip::ZipArchive::new(src_file)?;

    let out_file = std::fs::File::create(&temp_out)
        .with_context(|| format!("Creating temporary output at {temp_out}"))?;
    let mut zip_out = zip::ZipWriter::new(out_file);

    let mut stripped_files = 0;
    let mut stripped_bytes = 0u64;

    for i in 0..zip_in.len() {
        let mut entry = zip_in.by_index(i)?;
        let name = entry.name().to_string();

        if name.starts_with("lib/") {
            let parts: Vec<&str> = name.split('/').collect();
            if parts.len() >= 2 {
                let abi = parts[1];
                if ANDROID_ABIS.contains(&abi) && abi != target_arch {
                    stripped_files += 1;
                    stripped_bytes += entry.size();
                    continue;
                }
            }
        }

        let compression = entry.compression();
        let opts = SimpleFileOptions::default().compression_method(compression);

        zip_out.start_file(&name, opts)?;
        let mut buf = Vec::with_capacity(entry.size() as usize);
        entry.read_to_end(&mut buf)?;
        zip_out.write_all(&buf)?;
    }

    zip_out.finish()?;

    std::fs::remove_file(apk_path)?;
    std::fs::rename(&temp_out, apk_path)?;

    let final_size = std::fs::metadata(apk_path)?.len();
    let saved = initial_size.saturating_sub(final_size);

    info!(
        "Arch stripping complete: removed {stripped_files} libs ({stripped_bytes} uncompressed bytes). File shrunk by {saved} bytes ({initial_size} -> {final_size})."
    );

    Ok(saved)
}
