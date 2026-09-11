use anyhow::Result;
use std::path::Path;
use tracing::info;

pub fn clean_cache(all: bool) -> Result<()> {
    info!("Cleaning cache (all={all})...");
    if Path::new("tmp").exists() {
        std::fs::remove_dir_all("tmp")?;
        std::fs::create_dir_all("tmp")?;
    }
    if all && Path::new("tools").exists() {
        std::fs::remove_dir_all("tools")?;
        std::fs::create_dir_all("tools")?;
    }
    println!("Cache cleaned successfully.");
    Ok(())
}
