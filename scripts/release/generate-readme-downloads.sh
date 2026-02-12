#!/usr/bin/env bash
# ============================================
# README Downloads Generator
# ============================================
# Generates a beautiful downloads section for README.md
# with all APKs and modules from the latest build.
#
# Improvements over typical implementations:
# - Categorizes by app type (YouTube, Music, etc.)
# - Shows both APK and Magisk module variants
# - Includes version, architecture, size info
# - Badge-style download buttons
# - File checksums for verification
# - Responsive table design
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

# Configuration
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
README_FILE="${README_FILE:-${PROJECT_ROOT}/README.md}"
DOWNLOADS_MD="${DOWNLOADS_MD:-${PROJECT_ROOT}/DOWNLOADS.md}"
REPO_URL="${REPO_URL:-}"
RELEASE_TAG="${RELEASE_TAG:-latest-build}"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Detect repository URL
detect_repo_url() {
    if [[ -n "$REPO_URL" ]]; then
        echo "$REPO_URL"
        return
    fi
    
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        echo "https://github.com/${GITHUB_REPOSITORY}"
        return
    fi
    
    # Try to detect from git
    local url
    url=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$url" ]]; then
        # Convert SSH to HTTPS
        url=$(echo "$url" | sed -E 's|git@github\.com:|https://github.com/|;s|\.git$||')
        echo "$url"
        return
    fi
    
    echo ""
}

# Get human-readable file size
get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        du -h "$file" | cut -f1
    else
        echo "N/A"
    fi
}

# Get MD5 checksum (short version for display)
get_checksum() {
    local file="$1"
    if [[ -f "$file" ]] && command -v md5sum &>/dev/null; then
        md5sum "$file" | cut -c1-8
    else
        echo ""
    fi
}

# Parse app info from filename
# Format: appname-variant-revanced-vX.X.X-arch[-lite].apk/zip
parse_filename() {
    local filename="$1"
    local basename="${filename%.*}"
    local extension="${filename##*.}"
    
    # Initialize variables
    APP_NAME=""
    APP_VARIANT=""
    APP_VERSION=""
    APP_ARCH=""
    IS_LITE="false"
    IS_MODULE="false"
    FILE_TYPE="apk"
    
    # Check file type
    if [[ "$extension" == "zip" ]]; then
        IS_MODULE="true"
        FILE_TYPE="module"
    fi
    
    # Check if lite
    if [[ "$basename" == *"-lite"* ]]; then
        IS_LITE="true"
        basename="${basename%-lite}"
    fi
    
    # Check if module (from filename pattern)
    if [[ "$basename" == *"-module"* ]]; then
        IS_MODULE="true"
        FILE_TYPE="module"
        basename="${basename%-module}"
    fi
    
    # Extract architecture
    for arch in "arm64-v8a" "armeabi-v7a" "x86_64" "x86" "universal" "all"; do
        if [[ "$basename" == *"-$arch"* ]]; then
            APP_ARCH="$arch"
            basename="${basename%-$arch}"
            break
        fi
    done
    
    # Extract version (vX.X.X pattern)
    if [[ "$basename" =~ -v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        APP_VERSION="${BASH_REMATCH[1]}"
        basename="${basename%-v${APP_VERSION}}"
    fi
    
    # Remove -revanced suffix if present
    basename="${basename%-revanced}"
    
    # The rest is app name with variant
    APP_VARIANT="$basename"
    
    # Determine app category
    case "$basename" in
        *[Yy]outube*[Mm]usic*|*[Mm]usic*) APP_NAME="YouTube Music" ;;
        *[Yy]outube*) APP_NAME="YouTube" ;;
        *[Rr]eddit*) APP_NAME="Reddit" ;;
        *[Tt]ik[Tt]ok*) APP_NAME="TikTok" ;;
        *[Tt]witter*|*[Xx]-piko*) APP_NAME="X (Twitter)" ;;
        *[Ii]nstagram*) APP_NAME="Instagram" ;;
        *[Ff]acebook*) APP_NAME="Facebook" ;;
        *[Ss]potify*) APP_NAME="Spotify" ;;
        *[Ss]oundcloud*) APP_NAME="SoundCloud" ;;
        *[Gg]photos*|*[Pp]hotos*) APP_NAME="Google Photos" ;;
        *) APP_NAME="${basename}" ;;
    esac
}

# Get emoji for architecture
get_arch_emoji() {
    case "$1" in
        "arm64-v8a") echo "📱" ;;
        "armeabi-v7a") echo "📟" ;;
        "x86_64"|"x86") echo "💻" ;;
        "universal"|"all") echo "🌐" ;;
        *) echo "📦" ;;
    esac
}

# Get app logo (shields.io badge with logo)
get_app_logo() {
    local app="$1"
    local logo color
    case "$app" in
        "YouTube") logo="youtube"; color="FF0000" ;;
        "YouTube Music") logo="youtubemusic"; color="FF0000" ;;
        "Reddit") logo="reddit"; color="FF4500" ;;
        "X (Twitter)") logo="x"; color="000000" ;;
        "Instagram") logo="instagram"; color="E4405F" ;;
        "TikTok") logo="tiktok"; color="000000" ;;
        "Facebook") logo="facebook"; color="1877F2" ;;
        "Spotify") logo="spotify"; color="1DB954" ;;
        "SoundCloud") logo="soundcloud"; color="FF3300" ;;
        "Google Photos") logo="googlephotos"; color="4285F4" ;;
        *) logo="android"; color="3DDC84" ;;
    esac
    echo "![${app}](https://img.shields.io/badge/${app// /_}-${color}?style=flat-square&logo=${logo}&logoColor=white)"
}

# Generate download badge URL
generate_badge() {
    local label="$1"
    local color="${2:-blue}"
    local style="${3:-flat-square}"
    echo "https://img.shields.io/badge/${label}-${color}?style=${style}"
}

# Generate the downloads section
generate_downloads_section() {
    local repo_url="$1"
    local output=""
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    # Header
    output+="## 📥 Downloads\n\n"
    output+="> **Last Updated:** ${build_date}\n\n"
    
    # Quick links section
    output+="### 🔗 Quick Links\n\n"
    output+="| Resource | Link |\n"
    output+="|:---------|:-----|\n"
    output+="| 📦 All Releases | [![Releases](https://img.shields.io/badge/All_Releases-black?style=flat-square&logo=github)](${repo_url}/releases) |\n"
    output+="| 🔄 Latest Build | [![Latest](https://img.shields.io/badge/Latest_Build-blue?style=flat-square)](${repo_url}/releases/tag/${RELEASE_TAG}) |\n"
    output+="| 📱 MicroG RE | [![MicroG](https://img.shields.io/badge/MicroG_RE-green?style=flat-square)](https://github.com/MorpheApp/MicroG-RE/releases) |\n"
    output+="\n"
    
    # Requirements note
    output+="<details>\n<summary>📋 <b>Requirements & Installation</b></summary>\n\n"
    output+="#### Non-Root Installation\n"
    output+="1. Install [MicroG RE](https://github.com/MorpheApp/MicroG-RE/releases) first\n"
    output+="2. Download the APK for your device architecture\n"
    output+="3. Install the APK using your package manager\n\n"
    output+="#### Root Installation (Magisk/KernelSU)\n"
    output+="1. Download the \`.zip\` module file\n"
    output+="2. Install via Magisk/KernelSU app\n"
    output+="3. Reboot your device\n"
    output+="4. Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to block Play Store updates\n\n"
    output+="#### Architecture Guide\n"
    output+="| Arch | Description | Devices |\n"
    output+="|:----:|:------------|:--------|\n"
    output+="| 📱 ARM64 | 64-bit ARM | Most modern phones (2017+) |\n"
    output+="| 📟 ARM32 | 32-bit ARM | Older phones, some tablets |\n"
    output+="| 💻 x86_64 | 64-bit Intel | Chromebooks, emulators |\n"
    output+="| 🌐 Universal | All architectures | Works everywhere (larger size) |\n\n"
    output+="</details>\n\n"
    
    # Collect all files
    declare -A app_files
    local apps_order=()
    
    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file")
        parse_filename "$filename"
        
        if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
            apps_order+=("$APP_NAME")
        fi
        
        app_files["$APP_NAME"]+="${file}|"
    done
    
    if [[ ${#apps_order[@]} -eq 0 ]]; then
        output+="*No builds available yet. Run the build script first.*\n"
        echo -e "$output"
        return
    fi
    
    output+="---\n\n"
    
    # Generate tables for each app
    for app in "${apps_order[@]}"; do
        local app_logo
        app_logo=$(get_app_logo "$app")
        
        output+="### ${app_logo}\n\n"
        output+="| Type | Version | Architecture | Size | Download |\n"
        output+="|:----:|:-------:|:------------:|:----:|:--------:|\n"
        
        # Parse files for this app
        IFS='|' read -ra files <<< "${app_files[$app]}"
        for file in "${files[@]}"; do
            [[ -z "$file" ]] && continue
            [[ -f "$file" ]] || continue
            
            local filename
            filename=$(basename "$file")
            parse_filename "$filename"
            
            local size
            size=$(get_file_size "$file")
            local arch_emoji
            arch_emoji=$(get_arch_emoji "$APP_ARCH")
            local arch_display="${arch_emoji} ${APP_ARCH:-Universal}"
            
            # Type column
            local type_display
            if [[ "$IS_MODULE" == "true" ]]; then
                if [[ "$IS_LITE" == "true" ]]; then
                    type_display="⚡ Module Lite"
                else
                    type_display="🧩 Module"
                fi
            else
                if [[ "$IS_LITE" == "true" ]]; then
                    type_display="🪶 Lite"
                else
                    type_display="📦 Full"
                fi
            fi
            
            # Download link
            local download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            local badge_label
            badge_label=$(echo "⬇_Download" | sed 's/ /_/g')
            local download_badge="[![Download]($(generate_badge "$badge_label" "blue"))](${download_url})"
            
            output+="| ${type_display} | v${APP_VERSION:-N/A} | ${arch_display} | ${size} | ${download_badge} |\n"
        done
        
        output+="\n"
    done
    
    # Checksums section (collapsible)
    output+="<details>\n<summary>🔐 <b>File Checksums (MD5)</b></summary>\n\n"
    output+="\`\`\`\n"
    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file")
        if command -v md5sum &>/dev/null; then
            local checksum
            checksum=$(md5sum "$file" | awk '{print $1}')
            output+="${checksum}  ${filename}\n"
        fi
    done
    output+="\`\`\`\n\n"
    output+="</details>\n\n"
    
    # Footer
    output+="---\n\n"
    output+="<sub>📝 This section is automatically generated after each successful build.</sub>\n"
    
    echo -e "$output"
}

# Generate standalone DOWNLOADS.md
generate_downloads_md() {
    local repo_url="$1"
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    cat << EOF
### 📥 Available APKs

> **Last Updated:** ${build_date}

EOF
    
    # Generate tables for files
    declare -A app_files
    local apps_order=()
    
    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file")
        parse_filename "$filename"
        
        if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
            apps_order+=("$APP_NAME")
        fi
        
        app_files["$APP_NAME"]+="${file}|"
    done
    
    for app in "${apps_order[@]}"; do
        local app_logo
        app_logo=$(get_app_logo "$app")
        
        echo "### ${app_logo}"
        echo ""
        echo "| Type | Version | Architecture | Size | Download |"
        echo "|:----:|:-------:|:------------:|:----:|:--------:|"
        
        IFS='|' read -ra files <<< "${app_files[$app]}"
        for file in "${files[@]}"; do
            [[ -z "$file" ]] && continue
            [[ -f "$file" ]] || continue
            
            local filename
            filename=$(basename "$file")
            parse_filename "$filename"
            
            local size
            size=$(get_file_size "$file")
            local arch_emoji
            arch_emoji=$(get_arch_emoji "$APP_ARCH")
            local arch_display="${arch_emoji} ${APP_ARCH:-Universal}"
            
            local type_display
            if [[ "$IS_MODULE" == "true" ]]; then
                if [[ "$IS_LITE" == "true" ]]; then
                    type_display="⚡ Module Lite"
                else
                    type_display="🧩 Module"
                fi
            else
                if [[ "$IS_LITE" == "true" ]]; then
                    type_display="🪶 Lite"
                else
                    type_display="📦 Full"
                fi
            fi
            
            local download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            local download_badge="[![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](${download_url})"
            
            echo "| ${type_display} | v${APP_VERSION:-N/A} | ${arch_display} | ${size} | ${download_badge} |"
        done
        
        echo ""
    done
}

# Update README with downloads section
update_readme() {
    local repo_url="$1"
    local downloads_content
    downloads_content=$(generate_downloads_section "$repo_url")
    
    if [[ ! -f "$README_FILE" ]]; then
        warn "README.md not found, creating new file"
        echo -e "$downloads_content" > "$README_FILE"
        return
    fi
    
    # Check for markers in README
    local start_marker="<!-- DOWNLOADS_START -->"
    local end_marker="<!-- DOWNLOADS_END -->"
    
    if grep -q "$start_marker" "$README_FILE" && grep -q "$end_marker" "$README_FILE"; then
        # Replace content between markers
        local temp_file
        temp_file=$(mktemp)
        
        awk -v start="$start_marker" -v end="$end_marker" -v content="$downloads_content" '
            $0 ~ start { print; print content; skip=1; next }
            $0 ~ end { skip=0 }
            !skip { print }
        ' "$README_FILE" > "$temp_file"
        
        mv "$temp_file" "$README_FILE"
        log "Updated downloads section in README.md"
    else
        # Append to end of README with markers
        {
            echo ""
            echo "$start_marker"
            echo -e "$downloads_content"
            echo "$end_marker"
        } >> "$README_FILE"
        log "Appended downloads section to README.md"
    fi
}

# Main function
main() {
    log "Generating downloads documentation..."
    
    # Detect repository URL
    local repo_url
    repo_url=$(detect_repo_url)
    
    if [[ -z "$repo_url" ]]; then
        warn "Could not detect repository URL"
        warn "Set REPO_URL or GITHUB_REPOSITORY environment variable"
        repo_url="https://github.com/OWNER/REPO"
    fi
    
    info "Repository: $repo_url"
    info "Build directory: $BUILD_DIR"
    info "Release tag: $RELEASE_TAG"
    
    # Check build directory
    if [[ ! -d "$BUILD_DIR" ]]; then
        warn "Build directory not found: $BUILD_DIR"
        exit 0
    fi
    
    local file_count
    file_count=$(find "$BUILD_DIR" -maxdepth 1 \( -name "*.apk" -o -name "*.zip" \) 2>/dev/null | wc -l)
    
    if [[ $file_count -eq 0 ]]; then
        warn "No APK or ZIP files found in $BUILD_DIR"
        exit 0
    fi
    
    log "Found $file_count build artifacts"
    
    # Generate DOWNLOADS.md
    log "Generating DOWNLOADS.md..."
    generate_downloads_md "$repo_url" > "$DOWNLOADS_MD"
    log "Created: $DOWNLOADS_MD"
    
    # Update README.md
    log "Updating README.md..."
    update_readme "$repo_url"
    
    log "Done!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
