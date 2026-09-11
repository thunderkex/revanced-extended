use revancex::{builder, config, module, orchestrator, utils};
use std::io::Write;
use zip::write::SimpleFileOptions;

#[test]
fn test_config_loader_and_validation() {
    let cfg = config::load_config("./config").expect("Failed to load config");

    assert!(!cfg.apps.is_empty(), "Apps registry should not be empty");
    assert!(cfg.apps.len() >= 30, "Expected at least 30 configured apps");

    let youtube = cfg.apps.get("youtube").expect("youtube app missing");
    assert_eq!(youtube.package, "com.google.android.youtube");
    assert!(youtube.dependencies.contains(&"microg".to_string()));

    let microg = cfg.apps.get("microg").expect("microg app missing");
    assert_eq!(microg.package, "app.revanced.android.gms");

    let recorder = cfg.apps.get("google_recorder").expect("google_recorder app missing");
    assert_eq!(recorder.package, "com.google.android.apps.recorder");

    config::validate_config(&cfg, true).expect("Strict validation failed");
}

#[test]
fn test_semver_compatibility_logic() {
    assert!(utils::semver::check_compatibility("18.32.39", Some("18.0.0"), None));
    assert!(utils::semver::check_compatibility("v2.5.0", Some("2.0.0"), Some("3.0.0")));
    assert!(!utils::semver::check_compatibility("1.5.0", Some("2.0.0"), None));
    assert!(!utils::semver::check_compatibility("4.0.0", None, Some("3.5.0")));
}

#[test]
fn test_real_arch_stripping() {
    let tmp_dir = tempfile::tempdir().expect("Failed to create tempdir");
    let test_apk = tmp_dir.path().join("test-multiarch.apk");
    let test_apk_path = test_apk.to_str().unwrap();

    {
        let file = std::fs::File::create(&test_apk).unwrap();
        let mut zip = zip::ZipWriter::new(file);
        let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

        zip.start_file("AndroidManifest.xml", opts).unwrap();
        zip.write_all(b"dummy android manifest").unwrap();

        zip.start_file("lib/arm64-v8a/libnative.so", opts).unwrap();
        zip.write_all(&vec![0xAA; 5000]).unwrap();

        zip.start_file("lib/x86/libnative.so", opts).unwrap();
        zip.write_all(&vec![0xBB; 5000]).unwrap();

        zip.start_file("lib/x86_64/libnative.so", opts).unwrap();
        zip.write_all(&vec![0xCC; 5000]).unwrap();

        zip.start_file("lib/armeabi-v7a/libnative.so", opts).unwrap();
        zip.write_all(&vec![0xDD; 5000]).unwrap();

        zip.finish().unwrap();
    }

    let initial_size = std::fs::metadata(&test_apk).unwrap().len();

    let saved = builder::arch::strip_unsupported_archs(test_apk_path, "arm64-v8a")
        .expect("Arch stripping failed");

    assert!(saved > 0, "Stripping should save bytes");
    let final_size = std::fs::metadata(&test_apk).unwrap().len();
    assert!(final_size < initial_size, "Final size should be smaller than initial");

    let file = std::fs::File::open(&test_apk).unwrap();
    let mut archive = zip::ZipArchive::new(file).unwrap();

    let mut has_arm64 = false;
    let mut has_x86 = false;
    let mut has_v7a = false;

    for i in 0..archive.len() {
        let name = archive.by_index(i).unwrap().name().to_string();
        if name.contains("arm64-v8a") { has_arm64 = true; }
        if name.contains("x86") { has_x86 = true; }
        if name.contains("armeabi-v7a") { has_v7a = true; }
    }

    assert!(has_arm64, "arm64-v8a native lib should be preserved");
    assert!(!has_x86, "x86 native lib must be stripped");
    assert!(!has_v7a, "armeabi-v7a native lib must be stripped");
}

#[test]
fn test_real_lite_optimization() {
    let tmp_dir = tempfile::tempdir().expect("Failed to create tempdir");
    let test_apk = tmp_dir.path().join("test-bloated.apk");
    let test_apk_path = test_apk.to_str().unwrap();

    {
        let file = std::fs::File::create(&test_apk).unwrap();
        let mut zip = zip::ZipWriter::new(file);
        let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

        zip.start_file("classes.dex", opts).unwrap();
        zip.write_all(b"dex file bytecode").unwrap();

        zip.start_file("res/drawable-ldpi/icon.png", opts).unwrap();
        zip.write_all(&vec![0x11; 3000]).unwrap();

        zip.start_file("res/drawable-mdpi/icon.png", opts).unwrap();
        zip.write_all(&vec![0x22; 3000]).unwrap();

        zip.start_file("META-INF/CERT.RSA", opts).unwrap();
        zip.write_all(b"old cert signature").unwrap();

        zip.start_file("build-data.properties", opts).unwrap();
        zip.write_all(b"build.number=123").unwrap();

        zip.finish().unwrap();
    }

    let initial_size = std::fs::metadata(&test_apk).unwrap().len();

    let saved = builder::lite::optimize_apk(test_apk_path).expect("Lite optimization failed");

    assert!(saved > 0, "Lite optimization should save bytes");
    let final_size = std::fs::metadata(&test_apk).unwrap().len();
    assert!(final_size < initial_size, "Final size should be smaller than initial");

    let file = std::fs::File::open(&test_apk).unwrap();
    let mut archive = zip::ZipArchive::new(file).unwrap();

    for i in 0..archive.len() {
        let name = archive.by_index(i).unwrap().name().to_string();
        assert!(!name.contains("drawable-ldpi"), "drawable-ldpi must be removed");
        assert!(!name.contains("drawable-mdpi"), "drawable-mdpi must be removed");
        assert!(!name.ends_with(".RSA"), "CERT.RSA must be removed");
        assert!(!name.ends_with(".properties"), "properties must be removed");
    }
}

#[tokio::test]
async fn test_magisk_module_bundle_creation_and_verification() {
    let tmp_dir = tempfile::tempdir().expect("Failed to create tempdir");
    let out_dir = tmp_dir.path().to_str().unwrap();

    let apk1 = tmp_dir.path().join("app_one.apk");
    let apk2 = tmp_dir.path().join("app_two.apk");

    for apk_path in [&apk1, &apk2] {
        let file = std::fs::File::create(apk_path).unwrap();
        let mut zip = zip::ZipWriter::new(file);
        let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);
        zip.start_file("AndroidManifest.xml", opts).unwrap();
        zip.write_all(&vec![0x7F; 5000]).unwrap();
        zip.start_file("classes.dex", opts).unwrap();
        zip.write_all(&vec![0xAA; 10000]).unwrap();
        zip.finish().unwrap();
    }

    let cfg = config::load_config("./config").expect("Failed to load config");
    let apk_paths = format!("{},{}", apk1.to_str().unwrap(), apk2.to_str().unwrap());

    module::bundle::build_bundle_module(&cfg, &apk_paths, true, out_dir).await
        .expect("Failed to build bundle module");

    let mut found_zip = None;
    for entry in std::fs::read_dir(out_dir).unwrap() {
        let p = entry.unwrap().path();
        if p.extension().and_then(|e| e.to_str()) == Some("zip") {
            found_zip = Some(p);
            break;
        }
    }

    let zip_path = found_zip.expect("Expected a generated zip file in output directory");
    let zip_str = zip_path.to_str().unwrap();

    module::verify_bundle(zip_str).expect("Magisk module bundle verification failed");

    let file = std::fs::File::open(&zip_path).unwrap();
    let mut archive = zip::ZipArchive::new(file).unwrap();

    let mut has_update_binary = false;
    let mut has_updater_script = false;
    let mut has_module_prop = false;
    let mut has_customize_sh = false;
    let mut has_webui = false;
    let mut apk_entries = 0;

    for i in 0..archive.len() {
        let name = archive.by_index(i).unwrap().name().to_string();
        match name.as_str() {
            "META-INF/com/google/android/update-binary" => has_update_binary = true,
            "META-INF/com/google/android/updater-script" => has_updater_script = true,
            "module.prop" => has_module_prop = true,
            "customize.sh" => has_customize_sh = true,
            "webroot/index.html" => has_webui = true,
            _ => {
                if name.starts_with("apks/") && name.ends_with(".apk") {
                    apk_entries += 1;
                }
            }
        }
    }

    assert!(has_update_binary, "Missing update-binary in zip");
    assert!(has_updater_script, "Missing updater-script in zip");
    assert!(has_module_prop, "Missing module.prop in zip");
    assert!(has_customize_sh, "Missing customize.sh in zip");
    assert!(has_webui, "Missing webroot/index.html in zip");
    assert_eq!(apk_entries, 2, "Expected 2 APKs inside apks/");
}

#[tokio::test]
async fn test_matrix_generation_scenario() {
    let cfg = config::load_config("./config").expect("Failed to load config");
    orchestrator::generate_matrix(&cfg, "youtube,microg", "arm64-v8a", "full").await
        .expect("Matrix generation failed");
}
