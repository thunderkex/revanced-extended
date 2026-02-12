# 🚀 ReVanced Extended

<div align="center">

[![Build Status](https://img.shields.io/github/actions/workflow/status/thunderkex/revanced-extended/build.yml?style=for-the-badge&logo=github&label=Build)](https://github.com/thunderkex/revanced-extended/actions)
[![Latest Release](https://img.shields.io/github/v/release/thunderkex/revanced-extended?style=for-the-badge&logo=github&label=Latest)](https://github.com/thunderkex/revanced-extended/releases/tag/latest-build)
[![Downloads](https://img.shields.io/github/downloads/thunderkex/revanced-extended/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/thunderkex/revanced-extended/releases)
[![License](https://img.shields.io/github/license/thunderkex/revanced-extended?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/thunderkex/revanced-extended?style=for-the-badge&logo=github)](https://github.com/thunderkex/revanced-extended/stargazers)

**Auto-built ReVanced Extended APKs & Magisk Modules**

[📥 Downloads](#-downloads) • [📖 Documentation](#-documentation) • [🛠️ Build](#️-build-it-yourself) • [❓ FAQ](#-faq)

</div>

---

## ✨ Features

- 🔄 **Auto-Updated** - Builds triggered automatically when new patches are released
- 🧩 **Magisk/KernelSU Modules** - Root installation with auto-updates
- 📱 **Multiple Architectures** - ARM64, ARM32, x86, and Universal builds
- 🎨 **Morphe Patches** - Enhanced patches with additional features
- 🔒 **Verified Builds** - MD5 checksums provided for verification

---

## 📋 Supported Apps

| App | Patches Source | Status |
|:---:|:--------------|:------:|
| ![YouTube Music](https://img.shields.io/badge/YouTube_Music-FF0000?style=flat-square&logo=youtube-music&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![Reddit](https://img.shields.io/badge/Reddit-FF4500?style=flat-square&logo=reddit&logoColor=white) | [wchill/rvx-morphed](https://github.com/wchill/rvx-morphed) | ✅ Active |
| ![X](https://img.shields.io/badge/X_(Twitter)-000000?style=flat-square&logo=x&logoColor=white) | [crimera/piko](https://github.com/crimera/piko) | ✅ Active |

> 💡 Enable more apps by editing `config.toml`

---
# Dont use LITE variants for now
<!-- DOWNLOADS_START -->
## 📥 Downloads

> **Last Updated:** 2026-02-12 13:21:46 UTC

### 🔗 Quick Links

| Resource | Link |
|:---------|:-----|
| 📦 All Releases | [![Releases](https://img.shields.io/badge/All_Releases-black?style=flat-square&logo=github)](https://github.com/thunderkex/revanced-extended/releases) |
| 🔄 Latest Build | [![Latest](https://img.shields.io/badge/Latest_Build-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/tag/latest-build) |
| 📱 MicroG RE | [![MicroG](https://img.shields.io/badge/MicroG_RE-green?style=flat-square)](https://github.com/MorpheApp/MicroG-RE/releases) |

<details>
<summary>📋 <b>Requirements & Installation</b></summary>

#### Non-Root Installation
1. Install [MicroG RE](https://github.com/MorpheApp/MicroG-RE/releases) first
2. Download the APK for your device architecture
3. Install the APK using your package manager

#### Root Installation (Magisk/KernelSU)
1. Download the `.zip` module file
2. Install via Magisk/KernelSU app
3. Reboot your device
4. Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to block Play Store updates

#### Architecture Guide
| Arch | Description | Devices |
|:----:|:------------|:--------|
| 📱 ARM64 | 64-bit ARM | Most modern phones (2017+) |
| 📟 ARM32 | 32-bit ARM | Older phones, some tablets |
| 💻 x86_64 | 64-bit Intel | Chromebooks, emulators |
| 🌐 Universal | All architectures | Works everywhere (larger size) |

</details>

---

### ![YouTube Music](https://img.shields.io/badge/YouTube_Music-FF0000?style=flat-square&logo=youtubemusic&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v8.30.54 | 📱 arm64-v8a | 54M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/music-ex-morphed-revanced-v8.30.54-arm64-v8a.apk) |
| 🧩 Module | v8.30.54 | 📱 arm64-v8a | 72M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/music-ex-morphed-revanced-magisk-v8.30.54-arm64-v8a.zip) |

### ![SoundCloud](https://img.shields.io/badge/SoundCloud-FF3300?style=flat-square&logo=soundcloud&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v2025.05.27 | 📱 arm64-v8a | 76M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/soundcloud-revanced-v2025.05.27-release-arm64-v8a.apk) |
| 🧩 Module | v2025.05.27 | 📱 arm64-v8a | 114M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/soundcloud-revanced-magisk-v2025.05.27-release-arm64-v8a.zip) |

### ![Spotify](https://img.shields.io/badge/Spotify-1DB954?style=flat-square&logo=spotify&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v9.0.90 | 📱 arm64-v8a | 80M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/spotify-revanced-v9.0.90.1229-arm64-v8a.apk) |
| 🧩 Module | v9.0.90 | 📱 arm64-v8a | 137M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/spotify-revanced-magisk-v9.0.90.1229-arm64-v8a.zip) |

### ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)

| Type | Version | Architecture | Size | Download |
|:----:|:-------:|:------------:|:----:|:--------:|
| 📦 APK | v20.05.46 | 📱 arm64-v8a | 76M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/youtube-ex-morphed-revanced-v20.05.46-arm64-v8a.apk) |
| 🧩 Module | v20.05.46 | 📱 arm64-v8a | 112M | [![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](https://github.com/thunderkex/revanced-extended/releases/download/latest-build/youtube-ex-morphed-revanced-magisk-v20.05.46-arm64-v8a.zip) |

<details>
<summary>🔐 <b>File Checksums (MD5)</b></summary>

```
d9fe66122216b5484eb271fbe68b488d  music-ex-morphed-revanced-v8.30.54-arm64-v8a.apk
d7112e00f387781af6f697899789f7b4  soundcloud-revanced-v2025.05.27-release-arm64-v8a.apk
37bc1fb0e8d45a113b51eabf214cbea0  spotify-revanced-v9.0.90.1229-arm64-v8a.apk
af53f8212adbaf0249fdf69259e410bc  youtube-ex-morphed-revanced-v20.05.46-arm64-v8a.apk
629283410461277144378a1d3d78f3e7  music-ex-morphed-revanced-magisk-v8.30.54-arm64-v8a.zip
63f7d93c3878ce6a79823448881e18bc  soundcloud-revanced-magisk-v2025.05.27-release-arm64-v8a.zip
76521acc237e3b5edfdd5137729eddfd  spotify-revanced-magisk-v9.0.90.1229-arm64-v8a.zip
a0b04c312fe68d52cad510093ab1b5d3  youtube-ex-morphed-revanced-magisk-v20.05.46-arm64-v8a.zip
```

</details>

---

<sub>📝 This section is automatically generated after each successful build.</sub>
<!-- DOWNLOADS_END -->

---

## 📖 Documentation

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

## 🛠️ Build It Yourself

### Prerequisites

- Linux/macOS or [Termux](https://termux.dev/) on Android
- Java 17+ (`openjdk-17-jdk`)
- Required tools: `jq`, `curl`, `zip`

### Quick Start

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

### Build Options

```bash
# Clean build
./build.sh clean

# Resume interrupted build
./build.sh config.toml --resume

# Update patches config
./build.sh config.toml --config-update
```

### Termux Build

```bash
# Setup Termux environment first
pkg update && pkg upgrade
pkg install openjdk-17 git curl jq zip

# Then run
./build-termux.sh
```

---

## ❓ FAQ

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

## 🙏 Credits

- [ReVanced](https://github.com/revanced) - Original project
- [inotia00](https://github.com/inotia00) - ReVanced Extended patches
- [wchill](https://github.com/wchill) - RVX Morphed patches
- [MorpheApp](https://github.com/MorpheApp) - Morphe CLI & MicroG RE
- [j-hc](https://github.com/j-hc) - Build scripts & tools
- [crimera](https://github.com/crimera) - Piko Twitter patches

---

## 📄 License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**⭐ Star this repo if you find it useful!**

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-❤️-ea4aaa?style=for-the-badge)](https://github.com/sponsors/thunderkex)

</div>
