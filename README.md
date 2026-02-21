# ReVanced Extended: Android App Patching, Customization & Ad-Blocking

<div align="center">

[![Build Status](https://img.shields.io/github/actions/workflow/status/thunderkex/revanced-extended/build.yml?style=for-the-badge&logo=github&label=Build)](https://github.com/thunderkex/revanced-extended/actions)
[![Latest Release](https://img.shields.io/github/v/release/thunderkex/revanced-extended?style=for-the-badge&logo=github&label=Latest)](https://github.com/thunderkex/revanced-extended/releases/tag/latest-build)
[![Downloads](https://img.shields.io/github/downloads/thunderkex/revanced-extended/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/thunderkex/revanced-extended/releases)
[![License](https://img.shields.io/github/license/thunderkex/revanced-extended?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/thunderkex/revanced-extended?style=for-the-badge&logo=github)](https://github.com/thunderkex/revanced-extended/stargazers)

**Auto-built APKs, Magisk Modules, and Advanced Android App Customization Tools**

[📥 Downloads](#-download-revanced-extended-apks--modules) • [📖 Documentation](#-documentation-configuration--support) • [🛠️ Build](#️-build-revanced-extended-yourself) • [❓ FAQ](#-frequently-asked-questions-faq)

</div>

---

## ✨ Key Features & Benefits

- 🔄 **Auto-Updated**: Always up-to-date with the latest patches for popular Android apps (YouTube, Twitter, Reddit, Facebook, Instagram, Spotify, TikTok, and more)
- 🧩 **Magisk/KernelSU Modules**: Root installation, seamless updates, and advanced modding
- 📱 **Multi-Architecture Support**: ARM64, ARM32, x86, Universal APKs for maximum compatibility
- 🎨 **Enhanced Morphe Patches**: Unlock premium features, customize UI, and optimize app performance
- 🔒 **Verified Builds**: MD5 checksums for security and integrity
- 🚫 **Ad-Blocking & Privacy**: Remove ads, trackers, and enhance privacy in patched apps
- 🛠️ **Open-Source & Community-Driven**: Transparent development, frequent updates, and community support

---

## 📋 Supported Android Apps & Modules

| App | Patches Source | Status |
|:---:|:--------------|:------:|
| ![YouTube Music](https://img.shields.io/badge/YouTube_Music-FF0000?style=flat-square&logo=youtube-music&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![Reddit](https://img.shields.io/badge/Reddit-FF4500?style=flat-square&logo=reddit&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![X (Twitter)](https://img.shields.io/badge/X_(Twitter)-000000?style=flat-square&logo=x&logoColor=white) | [crimera/piko](https://github.com/crimera/piko) | ✅ Active |
| ![Facebook](https://img.shields.io/badge/Facebook-1877F2?style=flat-square&logo=facebook&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=flat-square&logo=instagram&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![Spotify](https://img.shields.io/badge/Spotify-1DB954?style=flat-square&logo=spotify&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![TikTok](https://img.shields.io/badge/TikTok-000000?style=flat-square&logo=tiktok&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![Google Photos](https://img.shields.io/badge/Google_Photos-4285F4?style=flat-square&logo=googlephotos&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![SoundCloud](https://img.shields.io/badge/SoundCloud-FF3300?style=flat-square&logo=soundcloud&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |
| ![Strava](https://img.shields.io/badge/Strava-FF7F00?style=flat-square&logo=strava&logoColor=white) | [revanced](https://github.com/revanced) | ✅ Active |

> 💡 Enable more apps and custom patches by editing `config.toml` (see [CONFIG.md](CONFIG.md))

---
# Dont use LITE variants for now
<!-- DOWNLOADS_START -->
## 📥 Download ReVanced Extended APKs & Modules

> **Last Updated:** 2026-02-21 16:52:32 UTC

### 🔗 Quick Links

| Resource | Link |
|:---------|:-----|
| 📦 All Releases | [![Releases](https://img.shields.io/badge/All_Releases-black?style=flat-square&logo=github)](https://github.com/thunderkex/revanced-extended/releases) |
| 🔄 Latest Build | [![Latest](https://img.shields.io/badge/Latest_Build-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/tag/latest-build) |
| 📱 MicroG RE | [![MicroG](https://img.shields.io/badge/MicroG_RE-green?style=flat-square)](https://github.com/MorpheApp/MicroG-RE/releases) |

<details>
<summary>📋 <b>Requirements & Installation</b></summary>

#### Non-Root Installation (Ad-Blocking, Customization)
1. Install [MicroG RE](https://github.com/MorpheApp/MicroG-RE/releases) for Google login support
2. Download the APK for your device architecture (ARM64, ARM32, x86, Universal)
3. Install the APK using your package manager

#### Root Installation (Magisk/KernelSU)
1. Download the `.zip` module file for your device
2. Install via Magisk/KernelSU app
3. Reboot your device
4. Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent unwanted Play Store updates

#### Architecture Guide (Device Compatibility)
| Arch | Description | Devices |
|:----:|:------------|:--------|
| 📱 ARM64 | 64-bit ARM | Most modern Android phones (2017+) |
| 📟 ARM32 | 32-bit ARM | Older Android phones, some tablets |
| 💻 x86_64 | 64-bit Intel | Chromebooks, emulators |
| 🌐 Universal | All architectures | Works everywhere (larger APK size) |

</details>

---

### ![Facebook](https://img.shields.io/badge/Facebook-1877F2?style=flat-square&logo=facebook&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v490.0.0 | 📱 arm64-v8a | 62M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/facebook-ex-revanced-v490.0.0.63.82-arm64-v8a.apk) |

### ![Google Photos](https://img.shields.io/badge/Google_Photos-4285F4?style=flat-square&logo=googlephotos&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v7.64.0 | 📱 arm64-v8a | 90M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/gphotos-ex-revanced-v7.64.0.870575488-arm64-v8a.apk) |

### ![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=flat-square&logo=instagram&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v417.0.0 | 📱 arm64-v8a | 136M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/instagram-ex-revanced-v417.0.0.54.77-arm64-v8a.apk) |

### ![lightroom-ex](https://img.shields.io/badge/lightroom-ex-3DDC84?style=flat-square&logo=android&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v9.3.0 | 📱 arm64-v8a | 129M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/lightroom-ex-revanced-v9.3.0-arm64-v8a.apk) |

### ![YouTube Music](https://img.shields.io/badge/YouTube_Music-FF0000?style=flat-square&logo=youtubemusic&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v8.30.54 | 📱 arm64-v8a | 54M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/music-ex-morphed-revanced-v8.30.54-arm64-v8a.apk) |
| 🧩 Module | v8.30.54 | 📱 arm64-v8a | 42M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/music-ex-morphed-revanced-magisk-v8.30.54-arm64-v8a.zip) |

### ![SoundCloud](https://img.shields.io/badge/SoundCloud-FF3300?style=flat-square&logo=soundcloud&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v2025.05.27 | 📱 arm64-v8a | 76M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/soundcloud-ex-revanced-v2025.05.27-release-arm64-v8a.apk) |

### ![Spotify](https://img.shields.io/badge/Spotify-1DB954?style=flat-square&logo=spotify&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v9.0.96 | 📱 arm64-v8a | 82M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/spotify-ex-revanced-v9.0.96.819-arm64-v8a.apk) |

### ![Strava](https://img.shields.io/badge/Strava-FC4C02?style=flat-square&logo=strava&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | vN/A | 📱 arm64-v8a | 123M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/strava-ex-revanced-v451.10-arm64-v8a.apk) |

### ![TikTok](https://img.shields.io/badge/TikTok-000000?style=flat-square&logo=tiktok&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v36.5.4 | 📱 arm64-v8a | 306M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/tiktok-revanced-v36.5.4-arm64-v8a.apk) |

### ![X (Twitter)](https://img.shields.io/badge/X_(Twitter)-000000?style=flat-square&logo=x&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v10.86.0 | 📱 arm64-v8a | 94M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/x-piko-revanced-v10.86.0-release.0-arm64-v8a.apk) |

### ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v20.05.46 | 📱 arm64-v8a | 90M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/youtube-ex-morphed-revanced-v20.05.46-arm64-v8a.apk) |
| 🧩 Module | v20.05.46 | 📱 arm64-v8a | 70M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/youtube-ex-morphed-revanced-magisk-v20.05.46-arm64-v8a.zip) |

<details>
<summary>🔐 <b>File Checksums (MD5)</b></summary>

```
4ca18f97a0cd30c2a416857716a12a25  facebook-ex-revanced-v490.0.0.63.82-arm64-v8a.apk
5af39e13267d7e84387217f03603b54d  gphotos-ex-revanced-v7.64.0.870575488-arm64-v8a.apk
684b58f4ca692acdf97bca4e48a66570  instagram-ex-revanced-v417.0.0.54.77-arm64-v8a.apk
2a5b704f960f271b3037638be61823c2  lightroom-ex-revanced-v9.3.0-arm64-v8a.apk
6b3d535aa8c4c5c96d00f86ae9a092fb  music-ex-morphed-revanced-v8.30.54-arm64-v8a.apk
6950e5ca643797e24fd551ed54da0926  soundcloud-ex-revanced-v2025.05.27-release-arm64-v8a.apk
f72e0ddcc624ea13b7a0109d47b323c1  spotify-ex-revanced-v9.0.96.819-arm64-v8a.apk
7d76e01f9108aa6f55d1a4bb9f12bc24  strava-ex-revanced-v451.10-arm64-v8a.apk
0cce72a8f61bb17c0355449c0b71ba6d  tiktok-revanced-v36.5.4-arm64-v8a.apk
c6e728e9467ab73208abf7ca7830db6d  x-piko-revanced-v10.86.0-release.0-arm64-v8a.apk
1a6962339c067a151559e71caeb3019a  youtube-ex-morphed-revanced-v20.05.46-arm64-v8a.apk
82ef425bc37101696d8f56dca78258a7  music-ex-morphed-revanced-magisk-v8.30.54-arm64-v8a.zip
9c8e93827a8a47687faa5ba9962defde  youtube-ex-morphed-revanced-magisk-v20.05.46-arm64-v8a.zip
```

</details>

---

<sub>📝 This section is automatically generated after each successful build.</sub>
<!-- DOWNLOADS_END -->

---

## 📖 Documentation, Configuration & Support

<details>
<summary><b>📁 Project Structure</b></summary>

```
. 
├── build.sh              # Main build script
├── build-termux.sh       # Termux-specific build script
├── config.toml           # Build configuration
├── utils.sh              # Utility functions
├── build/                # Built APKs output directory
├── temp/                 # Temporary build files
├── scripts/
│   ├── release/          # Release management scripts
│   └── utilities/        # Build utilities
└── revanced-magisk/      # Magisk module template
```

</details>

<details>
<summary><b>⚙️ Configuration Options</b></summary>

Key options in `config.toml`:

| Option | Description | Default |
|:-------|:------------|:--------|
| `default-arch` | Target architecture | `arm64-v8a` |
| `build-lite` | Build lite variants | `true` |
| `compression-level` | APK compression (0-9) | `9` |
| `parallel-jobs` | Parallel build jobs | Auto |
| `patches-source` | Patches repository | Per-app |

See [CONFIG.md](CONFIG.md) for full documentation.

</details>

<details>
<summary><b>🏗️ App Configuration</b></summary>

Each app in `config.toml` supports:

```toml
[YouTube-Music]
enabled = true                    # Enable/disable this app
build-mode = "both"              # apk, module, or both
arch = "arm64-v8a"               # Target architecture
patches-source = "user/repo"     # Patches source
cli-source = "user/repo"         # CLI source
included-patches = "'Patch1'"    # Patches to include
excluded-patches = "'Patch2'"    # Patches to exclude
```

</details>

---

## 🛠️ Build ReVanced Extended Yourself

### Prerequisites (Build Requirements)

- Linux/macOS or [Termux](https://termux.dev/) on Android
- Java 17+ (`openjdk-17-jdk`)
- Required tools: `jq`, `curl`, `zip`

### Quick Start (Build & Patch Android Apps)

```bash
# Clone the repository
git clone https://github.com/thunderkex/revanced-extended.git
cd revanced-extended

# Edit configuration (optional)
nano config.toml

# Run the build
./build.sh

# Built files will be in ./build/
```

### Build Options (Advanced Usage)

```bash
# Clean build
./build.sh clean

# Resume interrupted build
./build.sh config.toml --resume

# Update patches config
./build.sh config.toml --config-update
```

### Termux Build (Android CLI)

```bash
# Setup Termux environment first
pkg update && pkg upgrade
pkg install openjdk-17 git curl jq zip

# Then run
./build-termux.sh
```

---

## ❓ Frequently Asked Questions (FAQ)

<details>
<summary><b>Which architecture should I choose?</b></summary>

- **ARM64 (arm64-v8a)**: Most Android phones from 2017 onwards
- **ARM32 (armeabi-v7a)**: Older devices, some budget phones
- **x86_64**: Android emulators, Chromebooks
- **Universal**: Use if unsure (larger file size)

To check your device architecture:
```bash
adb shell getprop ro.product.cpu.abi
```
Or use an app like [CPU-Z](https://play.google.com/store/apps/details?id=com.cpuid.cpu_z).

</details>

<details>
<summary><b>Why do I need MicroG?</b></summary>

YouTube and YouTube Music require Google Play Services for account login. Since these patched apps use a different signature, regular Play Services won't work. MicroG is an open-source replacement that provides the necessary APIs.

**Download:** [MicroG RE](https://github.com/MorpheApp/MicroG-RE/releases)

</details>

<details>
<summary><b>How do I prevent Play Store updates?</b></summary>

For root users, install [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent the Play Store from updating the original apps.

For non-root users, disable auto-updates in Play Store settings or use ADB:
```bash
adb shell pm disable-user --user 0 com.android.vending
```

</details>

<details>
<summary><b>Having trouble with the classic mount method?</b></summary>

If you are experiencing issues such as:
- "Reflash needed" error after reboots
- "Suspicious mount detected" warnings from root detector apps

You can consider using [rvmm-zygisk-mount](https://github.com/inotia00/rvmm-zygisk-mount) as an alternative mount method.

</details>

<details>
<summary><b>Build failed - what should I do?</b></summary>

1. Run `./build.sh clean` and try again
2. Check disk space (need ~2GB free)
3. Ensure Java 17+ is installed: `java -version`
4. Check network connectivity
5. Try with `--resume` flag to skip completed steps
6. Check the [Issues](https://github.com/thunderkex/revanced-extended/issues) page

</details>

---

## 🙏 Credits & Acknowledgements

- [ReVanced](https://github.com/revanced) - Original project
- [inotia00](https://github.com/inotia00) - ReVanced Extended patches
- [wchill](https://github.com/wchill) - RVX Morphed patches
- [MorpheApp](https://github.com/MorpheApp) - Morphe CLI & MicroG RE
- [j-hc](https://github.com/j-hc) - Build scripts & tools
- [crimera](https://github.com/crimera) - Piko Twitter patches

---

## 📄 License

This project is licensed under the GPL-3.0 License. See the [LICENSE](LICENSE) file for full details.
---


<div align="center">

**⭐ Star this repo if you find it useful!**

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-❤️-ea4aaa?style=for-the-badge)](https://github.com/sponsors/thunderkex)

</div>
