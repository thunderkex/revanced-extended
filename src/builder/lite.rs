use anyhow::{Context, Result};
use std::io::{Read, Write};
use tracing::info;
use zip::write::SimpleFileOptions;

pub fn optimize_apk(apk_path: &str) -> Result<u64> {
    let initial_size = std::fs::metadata(apk_path)?.len();
    let temp_out = format!("{apk_path}.lite.tmp");

    info!("Running real lite optimization on {apk_path}...");

    let src_file = std::fs::File::open(apk_path)
        .with_context(|| format!("Opening APK at {apk_path}"))?;
    let mut zip_in = zip::ZipArchive::new(src_file)?;

    let out_file = std::fs::File::create(&temp_out)
        .with_context(|| format!("Creating temporary output at {temp_out}"))?;
    let mut zip_out = zip::ZipWriter::new(out_file);

    let mut removed_count = 0;
    let mut removed_bytes = 0u64;

    for i in 0..zip_in.len() {
        let mut entry = zip_in.by_index(i)?;
        let name = entry.name().to_string();

        let is_low_dpi = name.starts_with("res/drawable-ldpi")
            || name.starts_with("res/drawable-mdpi")
            || name.starts_with("res/drawable-tvdpi");

        let is_stale_sig = name.starts_with("META-INF/")
            && (name.ends_with(".SF") || name.ends_with(".RSA") || name.ends_with(".DSA") || name.ends_with(".EC"));

        let is_metadata = name.ends_with(".properties")
            || name.starts_with("assets/dexopt/")
            || name.contains("kotlin-tooling-metadata.json");

        if is_low_dpi || is_stale_sig || is_metadata {
            removed_count += 1;
            removed_bytes += entry.size();
            continue;
        }

        let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
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
        "Lite optimization complete: stripped {removed_count} bloated entries ({removed_bytes} raw bytes). File size: {initial_size} -> {final_size} (saved {saved} bytes)."
    );

    Ok(saved)
}
