use anyhow::{Context, Result};
use std::path::Path;
use tracing::info;

pub async fn sign_apk(apk_path: &str, keystore_path: &str, alias: &str, password: &str) -> Result<()> {
    info!("Signing APK {apk_path}...");

    let signer_jar = "tools/uber-apk-signer.jar";
    if Path::new(signer_jar).exists() {
        let status = tokio::process::Command::new("java")
            .args(["-jar", signer_jar, "-a", apk_path, "--overwrite"])
            .status()
            .await;
        if let Ok(s) = status {
            if s.success() {
                info!("APK signed successfully with uber-apk-signer: {apk_path}");
                return Ok(());
            }
        }
    }

    if Path::new(keystore_path).exists() {
        let apksigner_status = tokio::process::Command::new("apksigner")
            .args([
                "sign",
                "--ks", keystore_path,
                "--ks-key-alias", alias,
                "--ks-pass", &format!("pass:{password}"),
                "--key-pass", &format!("pass:{password}"),
                apk_path,
            ])
            .status()
            .await;

        if let Ok(s) = apksigner_status {
            if s.success() {
                info!("APK signed successfully with apksigner: {apk_path}");
                return Ok(());
            }
        }

        info!("apksigner not found or failed, using jarsigner fallback...");
        let jarsigner_status = tokio::process::Command::new("jarsigner")
            .args([
                "-keystore", keystore_path,
                "-storepass", password,
                "-keypass", password,
                apk_path,
                alias,
            ])
            .status()
            .await
            .context("Neither apksigner nor jarsigner found — install JDK")?;

        if !jarsigner_status.success() {
            anyhow::bail!("jarsigner failed to sign {apk_path}");
        }

        info!("APK signed successfully with jarsigner: {apk_path}");
    }

    Ok(())
}
