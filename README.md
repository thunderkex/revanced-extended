<p align="center">
  <img src="assets/logo.png" alt="ReVanceX" width="600" style="background: #ffffff; border-radius: 16px; padding: 16px;">
</p>

# ReVanceX

Modern, high-performance Rust patcher and orchestration ecosystem for ReVanced, Morphe, Magisk, and KernelSU modules with dynamic configurations, prebuilt binaries, and WebUI support.

## Features

- **40+ Pre-Configured Apps**: YouTube, YouTube Music, Spotify, Reddit, MicroG, Soundcloud, Twitter/X, and more.
- **Fast Rust CLI (`revancex`)**: High-performance local building, version resolution, and APK patching with no runtime dependencies beyond Java JDK 17.
- **Root & Non-Root Packaging**: Generate standalone signed APKs, individual Magisk/KernelSU modules, or multi-app bundle zips.
- **Embedded WebUI**: KernelSU and Magisk modules include an interactive, responsive WebUI for managing mounted apps.
- **Dynamic Configuration**: Fully decoupled definitions for apps (`apps.yaml`), patch profiles (`patches.yaml`), and upstream sources (`sources.yaml`).
- **Automated CI/CD**: Scheduled and on-demand builds via GitHub Actions with GitHub Pages catalogue.

---

## Guide: Building with Prebuilt CLI Binary

You do not need to install Rust or compile anything to build your patched APKs or root modules. Simply download the precompiled binary for your system.

### 1. Download & Installation

Download the latest precompiled CLI binary from [GitHub Releases](https://github.com/thunderkex/revancex/releases):

- **Linux (x86_64)**: [revancex-linux-x86_64.tar.gz](https://github.com/thunderkex/revancex/releases/latest/download/revancex-linux-x86_64.tar.gz)
- **Windows (x86_64)**: [revancex-windows-x86_64.zip](https://github.com/thunderkex/revancex/releases/latest/download/revancex-windows-x86_64.zip)

**Prerequisites**: Java JDK 17 or higher installed on your system.

#### Linux Setup
```bash
# Extract archive and mark as executable
tar -xzf revancex-linux-x86_64.tar.gz
chmod +x revancex
```

#### Windows Setup (PowerShell)
```powershell
# Extract archive
Expand-Archive revancex-windows-x86_64.zip -DestinationPath .
```

---

### 2. Discovering Supported Apps

Before building, you can view the complete catalogue of supported applications, package names, and their default patch sources:

- **List all supported apps**:
  ```bash
  ./revancex apps
  ```
  *(Outputs each app's internal ID, enabled status, and Android package name)*

- **Export app definitions as JSON**:
  ```bash
  ./revancex apps --json
  ```

- **Configuration File**:
  App definitions are stored in [`config/apps.yaml`](config/apps.yaml). You can customize patch sources (`revanced`, `revanced_extended`, `morphe`), target versions, or enable/disable apps directly in this file.

- **Web Catalogue**:
  Browse apps visually with the interactive web interface hosted on GitHub Pages or locally via `docs/index.html`.

---

### 3. Step-by-Step Build Workflow

#### Step 1: Download Required Tools & Patches
Download the required tools (revanced-cli, patch jars, apkeep, integrations) automatically:
```bash
./revancex download-tools
```
*(On Windows: `.\revancex.exe download-tools`)*

#### Step 2: Check for Upstream Updates (Optional)
Check if newer versions of apps or patch bundles are available upstream:
```bash
./revancex check-updates
```

#### Step 3: Build Patched APKs
Build your selected applications using the `build` subcommand:

- **Build specific applications**:
  ```bash
  ./revancex build --apps youtube,microg --arch arm64-v8a
  ```

- **Build all configured applications**:
  ```bash
  ./revancex build --apps all --arch arm64-v8a
  ```

- **Supported architectures (`--arch`)**:
  - `arm64-v8a` (Recommended for modern 64-bit Android devices)
  - `armeabi-v7a` (32-bit legacy devices)
  - `x86_64` (Emulators and Chromebooks)
  - `all` (Universal builds)

- **Optimization modes (`--mode`)**:
  - `--mode full`: Keeps all resources and languages (default).
  - `--mode lite`: Strips foreign architectures and unused language assets for minimal APK size.

- **Specify custom output folder**:
  ```bash
  ./revancex build --apps youtube --output ./my-output
  ```

#### Step 4: Create Magisk & KernelSU Modules (Root)
Package patched APKs into flashable root modules:

- **Single Root Module (one zip per app)**:
  ```bash
  ./revancex module --single --apps youtube --output ./modules
  ```

- **Multi-App Categorized Bundle Modules**:
  Build pre-categorized bundles (or custom app combinations) to keep module sizes lightweight and organized:
  ```bash
  # Build specific category bundles
  ./revancex module --bundle --apps social --output ./modules        # Social Media Bundle
  ./revancex module --bundle --apps multimedia --output ./modules    # Multimedia Bundle
  ./revancex module --bundle --apps productivity --output ./modules  # Productivity Bundle
  ./revancex module --bundle --apps tools --output ./modules         # Tools & Utilities Bundle
  ./revancex module --bundle --apps core --output ./modules          # Core Essentials Bundle
  ./revancex module --bundle --apps all --include-webui --output ./modules  # All Category Bundles
  ```

##### Bundle File Structure & Contents

Each bundle is a flashable Magisk, KernelSU, or APatch module zip structured as follows:

```text
revancex-bundle-<category>.zip
├── META-INF/com/google/android/
│   ├── update-binary            # Root flash installer script
│   └── updater-script           # #MAGISK header
├── module.prop                  # Module metadata (id, name, version, author)
├── customize.sh                 # Environment setup and installation routine
├── utils.sh                     # Dynamic bind-mount helper functions
├── service.sh                   # Boot service for active APK bind mounts
├── action.sh                    # Action button script for root managers
├── uninstall.sh                 # Clean unmount & file cleanup on module removal
├── apps.list                    # App package & mount mode mapping
├── webui/                       # Embedded management WebUI (if --include-webui is used)
└── apks/                        # Patched APK payloads mounted on top of stock base APKs
    ├── <app_1>.apk
    └── <app_2>.apk
```

##### Categorized Bundles Breakdown

| Bundle Name | Module Zip File | Apps Count | Payload Files Inside (`apks/`) | Included Applications |
| :--- | :--- | :--- | :--- | :--- |
| **Core Essentials Bundle** | `revancex-bundle.zip` | 5 Apps | • `apks/youtube.apk`<br>• `apks/youtube_music.apk`<br>• `apks/reddit.apk`<br>• `apks/spotify.apk`<br>• `apks/x_piko.apk` | YouTube, YouTube Music, Reddit, Spotify, X (Twitter) |
| **Multimedia Bundle** | `revancex-bundle-multimedia.zip` | 7 Apps | • `apks/youtube.apk`<br>• `apks/youtube_music.apk`<br>• `apks/youtube_morphed.apk`<br>• `apks/youtube_music_morphed.apk`<br>• `apks/spotify.apk`<br>• `apks/soundcloud.apk`<br>• `apks/prime_video.apk` | YouTube, YouTube Music, YouTube Morphed, YouTube Music Morphed, Spotify, SoundCloud, Prime Video |
| **Social Media Bundle** | `revancex-bundle-social.zip` | 7 Apps | • `apks/reddit.apk`<br>• `apks/tiktok.apk`<br>• `apks/instagram.apk`<br>• `apks/facebook.apk`<br>• `apks/threads.apk`<br>• `apks/x_piko.apk`<br>• `apks/pixiv.apk` | Reddit, TikTok, Instagram, Facebook, Threads, X (Twitter), Pixiv |
| **Productivity Bundle** | `revancex-bundle-productivity.zip` | 11 Apps | • `apks/wps_office.apk`<br>• `apks/camscanner.apk`<br>• `apks/solid_explorer.apk`<br>• `apks/fx_file_explorer.apk`<br>• `apks/rar.apk`<br>• `apks/google_photos.apk`<br>• `apks/lightroom.apk`<br>• `apks/google_recorder.apk`<br>• `apks/google_news.apk`<br>• `apks/terabox.apk`<br>• `apks/photomath.apk` | WPS Office, CamScanner, Solid Explorer, FX File Explorer, RAR, Google Photos, Lightroom, Google Recorder, Google News, TeraBox, Photomath |
| **Tools & Utilities Bundle** | `revancex-bundle-tools.zip` | 14 Apps | • `apks/adguard.apk`<br>• `apks/brave_browser.apk`<br>• `apks/proton_vpn.apk`<br>• `apks/psiphon.apk`<br>• `apks/battery_guru.apk`<br>• `apks/smart_launcher.apk`<br>• `apks/nova_launcher.apk`<br>• `apks/tasker.apk`<br>• `apks/waze.apk`<br>• `apks/truecaller.apk`<br>• `apks/eyecon_caller.apk`<br>• `apks/zalo.apk`<br>• `apks/strava.apk`<br>• `apks/myfitnesspal.apk` | AdGuard, Brave Browser, Proton VPN, Psiphon, Battery Guru, Smart Launcher, Nova Launcher, Tasker, Waze, Truecaller, Eyecon, Zalo, Strava, MyFitnessPal |


#### Step 5: Validate Configuration & Setup
Verify configuration syntax, app schemas, and patch integrity:
```bash
./revancex validate --strict
```

---

### 4. CLI Subcommand Reference

| Command | Description | Example |
| --- | --- | --- |
| `apps` | List all configured apps and package IDs | `revancex apps` |
| `download-tools` | Download patcher JARs, integrations, and tools | `revancex download-tools` |
| `check-updates` | Poll upstream sources for app and patch updates | `revancex check-updates --json` |
| `build` | Patch and sign target applications | `revancex build --apps youtube --arch arm64-v8a` |
| `module` | Package APKs into Magisk/KernelSU zip modules | `revancex module --bundle --apps youtube,microg` |
| `validate` | Check schema and config integrity | `revancex validate --strict` |
| `clean` | Clean up build artifacts and temporary files | `revancex clean` |

---

### 5. Build from Source (Developers)

If you prefer to compile the CLI from source:

```bash
# Prerequisites: Rust 1.75+ and JDK 17+
cargo build --release

# Run compiled binary
./target/release/revancex apps
./target/release/revancex download-tools
./target/release/revancex build --apps youtube,microg --arch arm64-v8a
```

### 3. GitHub Actions (Automated Cloud Builds)

1. Fork or push to this repository.
2. The GitHub Actions workflows run automatically:
   - **Auto Build**: Triggered on schedule or via `workflow_dispatch`.
   - **Custom Build**: Triggered via the GitHub Pages interface or `workflow_dispatch`.
   - **CI Validation & Tests**: Runs automated tests on every push.
3. Download the generated APKs and Magisk modules directly from the **Releases** tab.

### Environment Variables

Copy `.env.example` to `.env` and fill in values. Never commit `.env`.

| Variable | Description |
| --- | --- |
| `GITHUB_TOKEN` | Token with `repo` + `workflow` scopes |
| `KEYSTORE_PASSWORD` | Password for generated keystores |
| `TG_TOKEN` | (Optional) Telegram bot token for build notifications |
| `TG_CHAT` | (Optional) Telegram chat ID or channel username |
| `TG_TOPIC` | (Optional) Telegram topic / thread ID for forum supergroups |

## Adding an App

Add an entry to `config/apps.yaml` following the existing pattern. Run `validate` to check.

## Patch Sources

| ID | Repo |
| --- | --- |
| `revanced` | ReVanced/revanced-patches |
| `revanced_extended` | inotia00/revanced-patches |
| `morphe` | crimera/piko |

<!-- AUTO-APP-LIST-START -->

### 📱 Stock Apps & Single Root Modules

| App | Stock APK | Single Root Module | Last Updated |
| :--- | :--- | :--- | :--- |
| **Adguard** | [adguard.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/adguard.apk) | [revancex-module-adguard.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-adguard.zip) | 2026-09-11 10:31:11 UTC |
| **Battery Guru** | [battery_guru-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/battery_guru-patched.apk) | [revancex-module-battery_guru.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-battery_guru.zip) | 2026-09-11 10:31:11 UTC |
| **Brave Browser** | [brave_browser.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/brave_browser.apk) | [revancex-module-brave_browser.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-brave_browser.zip) | 2026-09-11 10:31:11 UTC |
| **Camscanner** | [camscanner-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/camscanner-patched.apk) | [revancex-module-camscanner.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-camscanner.zip) | 2026-09-11 10:31:11 UTC |
| **Eyecon Caller** | [eyecon_caller-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/eyecon_caller-patched.apk) | [revancex-module-eyecon_caller.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-eyecon_caller.zip) | 2026-09-11 10:31:11 UTC |
| **Facebook** | [facebook-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/facebook-patched.apk) | [revancex-module-facebook.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-facebook.zip) | 2026-09-11 10:31:11 UTC |
| **Fx File Explorer** | [fx_file_explorer-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/fx_file_explorer-patched.apk) | [revancex-module-fx_file_explorer.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-fx_file_explorer.zip) | 2026-09-11 10:31:11 UTC |
| **Google News** | [google_news-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/google_news-patched.apk) | [revancex-module-google_news.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-google_news.zip) | 2026-09-11 10:31:11 UTC |
| **Google Photos** | [google_photos-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/google_photos-patched.apk) | [revancex-module-google_photos.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-google_photos.zip) | 2026-09-11 10:31:11 UTC |
| **Google Recorder** | [google_recorder-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/google_recorder-patched.apk) | [revancex-module-google_recorder.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-google_recorder.zip) | 2026-09-11 10:31:11 UTC |
| **Instagram** | [instagram-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/instagram-patched.apk) | [revancex-module-instagram.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-instagram.zip) | 2026-09-11 10:31:11 UTC |
| **Lightroom** | [lightroom.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/lightroom.apk) | [revancex-module-lightroom.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-lightroom.zip) | 2026-09-11 10:31:11 UTC |
| **Microg** | [microg.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/microg.apk) | — | 2026-09-11 10:31:11 UTC |
| **Myfitnesspal** | [myfitnesspal-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/myfitnesspal-patched.apk) | [revancex-module-myfitnesspal.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-myfitnesspal.zip) | 2026-09-11 10:31:11 UTC |
| **Nova Launcher** | [nova_launcher-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/nova_launcher-patched.apk) | [revancex-module-nova_launcher.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-nova_launcher.zip) | 2026-09-11 10:31:11 UTC |
| **Photomath** | [photomath-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/photomath-patched.apk) | [revancex-module-photomath.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-photomath.zip) | 2026-09-11 10:31:11 UTC |
| **Pixiv** | [pixiv-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/pixiv-patched.apk) | [revancex-module-pixiv.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-pixiv.zip) | 2026-09-11 10:31:11 UTC |
| **Prime Video** | [prime_video-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/prime_video-patched.apk) | [revancex-module-prime_video.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-prime_video.zip) | 2026-09-11 10:31:11 UTC |
| **Proton Vpn** | [proton_vpn-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/proton_vpn-patched.apk) | [revancex-module-proton_vpn.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-proton_vpn.zip) | 2026-09-11 10:31:11 UTC |
| **Psiphon** | [psiphon.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/psiphon.apk) | [revancex-module-psiphon.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-psiphon.zip) | 2026-09-11 10:31:11 UTC |
| **Rar** | [rar-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/rar-patched.apk) | [revancex-module-rar.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-rar.zip) | 2026-09-11 10:31:11 UTC |
| **Reddit** | [reddit-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/reddit-patched.apk) | [revancex-module-reddit.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-reddit.zip) | 2026-09-11 10:31:11 UTC |
| **Smart Launcher** | [smart_launcher-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/smart_launcher-patched.apk) | [revancex-module-smart_launcher.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-smart_launcher.zip) | 2026-09-11 10:31:11 UTC |
| **Solid Explorer** | [solid_explorer-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/solid_explorer-patched.apk) | [revancex-module-solid_explorer.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-solid_explorer.zip) | 2026-09-11 10:31:11 UTC |
| **Soundcloud** | [soundcloud-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/soundcloud-patched.apk) | [revancex-module-soundcloud.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-soundcloud.zip) | 2026-09-11 10:31:11 UTC |
| **Spotify** | [spotify.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/spotify.apk) | [revancex-module-spotify.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-spotify.zip) | 2026-09-11 10:31:11 UTC |
| **Strava** | [strava-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/strava-patched.apk) | [revancex-module-strava.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-strava.zip) | 2026-09-11 10:31:11 UTC |
| **Tasker** | [tasker-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/tasker-patched.apk) | [revancex-module-tasker.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-tasker.zip) | 2026-09-11 10:31:11 UTC |
| **Terabox** | [terabox-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/terabox-patched.apk) | [revancex-module-terabox.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-terabox.zip) | 2026-09-11 10:31:11 UTC |
| **Threads** | [threads-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/threads-patched.apk) | [revancex-module-threads.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-threads.zip) | 2026-09-11 10:31:11 UTC |
| **Tiktok** | [tiktok-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/tiktok-patched.apk) | [revancex-module-tiktok.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-tiktok.zip) | 2026-09-11 10:31:11 UTC |
| **Truecaller** | [truecaller-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/truecaller-patched.apk) | [revancex-module-truecaller.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-truecaller.zip) | 2026-09-11 10:31:11 UTC |
| **Waze** | [waze-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/waze-patched.apk) | [revancex-module-waze.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-waze.zip) | 2026-09-11 10:31:11 UTC |
| **Wps Office** | [wps_office-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/wps_office-patched.apk) | [revancex-module-wps_office.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-wps_office.zip) | 2026-09-11 10:31:11 UTC |
| **X Piko** | [x_piko-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/x_piko-patched.apk) | [revancex-module-x_piko.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-x_piko.zip) | 2026-09-11 10:31:11 UTC |
| **Youtube** | [youtube-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/youtube-patched.apk) | [revancex-module-youtube.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-youtube.zip) | 2026-09-11 10:31:11 UTC |
| **Youtube Morphed** | [youtube_morphed-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/youtube_morphed-patched.apk) | [revancex-module-youtube_morphed.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-youtube_morphed.zip) | 2026-09-11 10:31:11 UTC |
| **Youtube Music** | [youtube_music-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/youtube_music-patched.apk) | [revancex-module-youtube_music.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-youtube_music.zip) | 2026-09-11 10:31:11 UTC |
| **Youtube Music Morphed** | [youtube_music_morphed-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/youtube_music_morphed-patched.apk) | [revancex-module-youtube_music_morphed.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-youtube_music_morphed.zip) | 2026-09-11 10:31:11 UTC |
| **Zalo** | [zalo-patched.apk](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/zalo-patched.apk) | [revancex-module-zalo.zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-module-zalo.zip) | 2026-09-11 10:31:11 UTC |



### 📦 Bundle Modules (Multi-App)

| Bundle Name | Included Apps & Payload Files | Download Link | Release Tag | Updated At |
| :--- | :--- | :--- | :--- | :--- |
| **Multimedia Bundle**<br><code>revancex-bundle-multimedia.zip</code> | <details><summary><b>7 Apps / APKs (Click to view)</b></summary><ul><li><b>YouTube</b>: <code>apks/youtube.apk</code></li><li><b>YouTube Music</b>: <code>apks/youtube_music.apk</code></li><li><b>YouTube Morphed</b>: <code>apks/youtube_morphed.apk</code></li><li><b>YouTube Music Morphed</b>: <code>apks/youtube_music_morphed.apk</code></li><li><b>Spotify</b>: <code>apks/spotify.apk</code></li><li><b>SoundCloud</b>: <code>apks/soundcloud.apk</code></li><li><b>Prime Video</b>: <code>apks/prime_video.apk</code></li></ul></details> | [Download Zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-bundle-multimedia.zip) | `auto-v1.0.4-2026.09.11-b18` | 2026-09-11 10:31:11 UTC |
| **Productivity Bundle**<br><code>revancex-bundle-productivity.zip</code> | <details><summary><b>11 Apps / APKs (Click to view)</b></summary><ul><li><b>WPS Office</b>: <code>apks/wps_office.apk</code></li><li><b>CamScanner</b>: <code>apks/camscanner.apk</code></li><li><b>Solid Explorer</b>: <code>apks/solid_explorer.apk</code></li><li><b>FX File Explorer</b>: <code>apks/fx_file_explorer.apk</code></li><li><b>RAR</b>: <code>apks/rar.apk</code></li><li><b>Google Photos</b>: <code>apks/google_photos.apk</code></li><li><b>Lightroom</b>: <code>apks/lightroom.apk</code></li><li><b>Google Recorder</b>: <code>apks/google_recorder.apk</code></li><li><b>Google News</b>: <code>apks/google_news.apk</code></li><li><b>TeraBox</b>: <code>apks/terabox.apk</code></li><li><b>Photomath</b>: <code>apks/photomath.apk</code></li></ul></details> | [Download Zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-bundle-productivity.zip) | `auto-v1.0.4-2026.09.11-b18` | 2026-09-11 10:31:11 UTC |
| **Social Media Bundle**<br><code>revancex-bundle-social.zip</code> | <details><summary><b>7 Apps / APKs (Click to view)</b></summary><ul><li><b>Reddit</b>: <code>apks/reddit.apk</code></li><li><b>TikTok</b>: <code>apks/tiktok.apk</code></li><li><b>Instagram</b>: <code>apks/instagram.apk</code></li><li><b>Facebook</b>: <code>apks/facebook.apk</code></li><li><b>Threads</b>: <code>apks/threads.apk</code></li><li><b>X (Twitter)</b>: <code>apks/x_piko.apk</code></li><li><b>Pixiv</b>: <code>apks/pixiv.apk</code></li></ul></details> | [Download Zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-bundle-social.zip) | `auto-v1.0.4-2026.09.11-b18` | 2026-09-11 10:31:11 UTC |
| **Tools & Utilities Bundle**<br><code>revancex-bundle-tools.zip</code> | <details><summary><b>14 Apps / APKs (Click to view)</b></summary><ul><li><b>AdGuard</b>: <code>apks/adguard.apk</code></li><li><b>Brave Browser</b>: <code>apks/brave_browser.apk</code></li><li><b>Proton VPN</b>: <code>apks/proton_vpn.apk</code></li><li><b>Psiphon</b>: <code>apks/psiphon.apk</code></li><li><b>Battery Guru</b>: <code>apks/battery_guru.apk</code></li><li><b>Smart Launcher</b>: <code>apks/smart_launcher.apk</code></li><li><b>Nova Launcher</b>: <code>apks/nova_launcher.apk</code></li><li><b>Tasker</b>: <code>apks/tasker.apk</code></li><li><b>Waze</b>: <code>apks/waze.apk</code></li><li><b>Truecaller</b>: <code>apks/truecaller.apk</code></li><li><b>Eyecon</b>: <code>apks/eyecon_caller.apk</code></li><li><b>Zalo</b>: <code>apks/zalo.apk</code></li><li><b>Strava</b>: <code>apks/strava.apk</code></li><li><b>MyFitnessPal</b>: <code>apks/myfitnesspal.apk</code></li></ul></details> | [Download Zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-bundle-tools.zip) | `auto-v1.0.4-2026.09.11-b18` | 2026-09-11 10:31:11 UTC |
| **Core Essentials Bundle**<br><code>revancex-bundle.zip</code> | <details><summary><b>5 Apps / APKs (Click to view)</b></summary><ul><li><b>YouTube</b>: <code>apks/youtube.apk</code></li><li><b>YouTube Music</b>: <code>apks/youtube_music.apk</code></li><li><b>Reddit</b>: <code>apks/reddit.apk</code></li><li><b>Spotify</b>: <code>apks/spotify.apk</code></li><li><b>X (Twitter)</b>: <code>apks/x_piko.apk</code></li></ul></details> | [Download Zip](https://github.com/thunderkex/revancex/releases/download/auto-v1.0.4-2026.09.11-b18/revancex-bundle.zip) | `auto-v1.0.4-2026.09.11-b18` | 2026-09-11 10:31:11 UTC |



### 🛠️ Custom Bundle Modules

| Custom Bundle | Download Link | Release Tag | Updated At |
| :--- | :--- | :--- | :--- |
| _None yet_ | — | — | — |

<!-- AUTO-APP-LIST-END -->
