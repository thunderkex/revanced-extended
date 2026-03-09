set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
README_FILE="${README_FILE:-${PROJECT_ROOT}/README.md}"
DOWNLOADS_MD="${DOWNLOADS_MD:-${PROJECT_ROOT}/DOWNLOADS.md}"
REPO_URL="${REPO_URL:-}"
RELEASE_TAG="${RELEASE_TAG:-latest-build}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

detect_repo_url() {
    if [[ -n "$REPO_URL" ]]; then
        echo "$REPO_URL"
        return
    fi
    
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        echo "https://github.com/${GITHUB_REPOSITORY}"
        return
    fi
    
    local url
    url=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$url" ]]; then
        url=$(echo "$url" | sed -E 's|git@github\.com:|https://github.com/|;s|\.git$||')
        echo "$url"
        return
    fi
    
    echo ""
}

get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        du -h "$file" | cut -f1
    else
        echo "N/A"
    fi
}

get_checksum() {
    local file="$1"
    if [[ -f "$file" ]] && command -v md5sum &>/dev/null; then
        md5sum "$file" | cut -c1-8
    else
        echo ""
    fi
}

fetch_release_assets() {
    [[ -z "${GITHUB_REPOSITORY:-}" ]] && return 1
    command -v gh &>/dev/null      || return 1
    command -v jq &>/dev/null      || return 1

    local response
    response=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" 2>/dev/null) || return 1

    echo "$response" | jq -r '
        .assets[] |
        select(.name | test("\\.(apk|zip)$")) |
        .size as $b |
        (if   $b > 1048576 then "\($b / 1048576 | floor)MB"
         elif $b > 1024    then "\($b / 1024    | floor)KB"
         else                   "\($b)B"
         end) as $sz |
        "\(.name)|||\($sz)|||\(.browser_download_url)"
    ' 2>/dev/null
}

parse_filename() {
    local filename="$1"
    local basename="${filename%.*}"
    local extension="${filename##*.}"
    
    APP_NAME=""
    APP_VARIANT=""
    APP_VERSION=""
    APP_ARCH=""
    IS_LITE="false"
    IS_MODULE="false"
    FILE_TYPE="apk"
    
    if [[ "$extension" == "zip" ]]; then
        IS_MODULE="true"
        FILE_TYPE="module"
    fi
    
    if [[ "$basename" == *"-lite"* ]]; then
        IS_LITE="true"
        basename="${basename%-lite}"
    fi
    
    if [[ "$basename" == *"-module"* ]]; then
        IS_MODULE="true"
        FILE_TYPE="module"
        basename="${basename%-module}"
    fi
    
    for arch in "arm64-v8a" "armeabi-v7a" "x86_64" "x86" "universal" "all"; do
        if [[ "$basename" == *"-$arch"* ]]; then
            APP_ARCH="$arch"
            basename="${basename%-$arch}"
            break
        fi
    done
    
    if [[ "$basename" =~ -v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        APP_VERSION="${BASH_REMATCH[1]}"
        basename="${basename%-v${APP_VERSION}}"
    elif [[ "$basename" =~ -v([0-9]{8}) ]]; then
        APP_VERSION="${BASH_REMATCH[1]}"
        basename="${basename%-v${APP_VERSION}}"
    fi
    
    basename="${basename%-revanced}"
    
    APP_VARIANT="$basename"
    
    case "$basename" in
        *revpack*) APP_NAME="RevPack"; APP_ARCH="all" ;;
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
        *[Ss]trava*) APP_NAME="Strava" ;;
        *) APP_NAME="${basename}" ;;
    esac
}

get_arch_emoji() {
    case "$1" in
        "arm64-v8a") echo "📱" ;;
        "armeabi-v7a") echo "📟" ;;
        "x86_64"|"x86") echo "💻" ;;
        "universal"|"all") echo "🌐" ;;
        *) echo "📦" ;;
    esac
}

get_app_logo() {
    local app="$1"
    local logo color
    case "$app" in
        "YouTube") logo="youtube"; color="FF0000" ;;
        "YouTube Music") logo="youtubemusic"; color="FF0000" ;;
        "RevPack") logo="android"; color="7C4DFF" ;;
        "Reddit") logo="reddit"; color="FF4500" ;;
        "X (Twitter)") logo="x"; color="000000" ;;
        "Instagram") logo="instagram"; color="E4405F" ;;
        "TikTok") logo="tiktok"; color="000000" ;;
        "Facebook") logo="facebook"; color="1877F2" ;;
        "Spotify") logo="spotify"; color="1DB954" ;;
        "SoundCloud") logo="soundcloud"; color="FF3300" ;;
        "Google Photos") logo="googlephotos"; color="4285F4" ;;
        "Strava") logo="strava"; color="FC4C02" ;;
        *) logo="android"; color="3DDC84" ;;
    esac
    echo "![${app}](https://img.shields.io/badge/${app// /_}-${color}?style=flat-square&logo=${logo}&logoColor=white)"
}

generate_badge() {
    local label="$1"
    local color="${2:-blue}"
    local style="${3:-flat-square}"
    echo "https://img.shields.io/badge/${label}-${color}?style=${style}"
}

generate_downloads_section() {
    local repo_url="$1"
    local output=""
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    output+="## 📥 Download ReVanced Extended APKs & Modules\n\n"
    output+="> **Last Updated:** ${build_date}\n\n"

    local recent_changes_lines
    recent_changes_lines=$(git -C "$PROJECT_ROOT" log --format="%h|%s|%ad" --date=short 2>/dev/null | \
        grep -v "GitHub Action" | \
        head -5 | \
        while IFS='|' read -r hash subject date; do
            echo "- [\`${hash}\`](${repo_url}/commit/${hash}) ${subject} (${date})"
        done)
    if [[ -n "$recent_changes_lines" ]]; then
        output+="### 📝 Recent Changes\n\n"
        output+="${recent_changes_lines}\n\n"
    fi

    output+="### 🔗 Quick Links\n\n"
    output+="| Resource | Link |\n"
    output+="|:---------|:-----|\n"
    output+="| 📦 All Releases | [![Releases](https://img.shields.io/badge/All_Releases-black?style=flat-square&logo=github)](${repo_url}/releases) |\n"
    output+="| 🔄 Latest Build | [![Latest](https://img.shields.io/badge/Latest_Build-blue?style=flat-square)](${repo_url}/releases/tag/${RELEASE_TAG}) |\n"
    output+="| 📱 MicroG RE | [![MicroG](https://img.shields.io/badge/MicroG_RE-green?style=flat-square)](https://github.com/MorpheApp/MicroG-RE/releases) |\n"
    output+="\n"
    
    output+="<details>\n<summary>📋 <b>Requirements & Installation</b></summary>\n\n"
    output+="#### Non-Root Installation (Ad-Blocking, Customization)\n"
    output+="1. Install [MicroG RE](https://github.com/MorpheApp/MicroG-RE/releases) for Google login support\n"
    output+="2. Download the APK for your device architecture (ARM64, ARM32, x86, Universal)\n"
    output+="3. Install the APK using your package manager\n\n"
    output+="#### Root Installation (Magisk/KernelSU)\n"
    output+="1. Download the \`.zip\` module file for your device\n"
    output+="2. Install via Magisk/KernelSU app\n"
    output+="3. Reboot your device\n"
    output+="4. Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent unwanted Play Store updates\n\n"
    output+="#### Architecture Guide (Device Compatibility)\n"
    output+="| Arch | Description | Devices |\n"
    output+="|:----:|:------------|:--------|\n"
    output+="| 📱 ARM64 | 64-bit ARM | Most modern Android phones (2017+) |\n"
    output+="| 📟 ARM32 | 32-bit ARM | Older Android phones, some tablets |\n"
    output+="| 💻 x86_64 | 64-bit Intel | Chromebooks, emulators |\n"
    output+="| 🌐 Universal | All architectures | Works everywhere (larger APK size) |\n\n"
    output+="</details>\n\n"
    
       declare -A app_files
    declare -A _seen_filenames
    local apps_order=()
    local custom_revpack_entries=()

    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file")
        if [[ "$filename" == *"-custom-"*.zip ]]; then
            local _lfsize _lfurl
            _lfsize=$(get_file_size "$file")
            _lfurl="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            custom_revpack_entries+=("${filename}|||${_lfsize}|||${_lfurl}")
            _seen_filenames["$filename"]=1
            continue
        fi
        parse_filename "$filename"
        _seen_filenames["$filename"]=1

        if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
            apps_order+=("$APP_NAME")
        fi
        app_files["$APP_NAME"]+="local:${file}|"
    done

    if [[ "${USE_RELEASE_ASSETS:-false}" == "true" ]]; then
        local _release_lines
        _release_lines=$(fetch_release_assets 2>/dev/null) || _release_lines=""

        while IFS= read -r _line; do
            [[ -z "$_line" ]] && continue
            local _rname _rsize _rurl
            _rname=$(echo "$_line" | awk -F'\|\|\|' '{print $1}')
            _rsize=$(echo "$_line" | awk -F'\|\|\|' '{print $2}')
            _rurl=$(echo  "$_line" | awk -F'\|\|\|' '{print $3}')

            [[ -n "${_seen_filenames[$_rname]+x}" ]] && continue

            if [[ "$_rname" == *"-custom-"*.zip ]]; then
                custom_revpack_entries+=("${_rname}|||${_rsize}|||${_rurl}")
                continue
            fi

            parse_filename "$_rname"
            if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
                apps_order+=("$APP_NAME")
            fi
            app_files["$APP_NAME"]+="release:${_rname}|||${_rsize}|||${_rurl}|"
        done <<< "$_release_lines"
    fi

    if [[ ${#apps_order[@]} -eq 0 ]]; then
        output+="*No builds available yet. Run the build script first.*\n"
        echo -e "$output"
        return
    fi

    output+="---\n\n"

    if [[ -n "${app_files[RevPack]+x}" ]]; then
        local revpack_rows=""
        IFS='|' read -ra _entries <<< "${app_files[RevPack]}"
        for _entry in "${_entries[@]}"; do
            [[ -z "$_entry" ]] && continue
            local filename size download_url
            if [[ "$_entry" == local:* ]]; then
                local file="${_entry#local:}"
                [[ -f "$file" ]] || continue
                filename=$(basename "$file")
                parse_filename "$filename"
                size=$(get_file_size "$file")
                download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            elif [[ "$_entry" == release:* ]]; then
                local _rdata="${_entry#release:}"
                filename=$(echo "$_rdata" | awk -F'\|\|\|' '{print $1}')
                size=$(echo    "$_rdata" | awk -F'\|\|\|' '{print $2}')
                download_url=$(echo "$_rdata" | awk -F'\|\|\|' '{print $3}')
                parse_filename "$filename"
            else
                continue
            fi
            [[ -z "$download_url" ]] && continue
            local badge_label
            badge_label=$(echo "⬇_Download" | sed 's/ /_/g')
            local download_badge="[![Download]($(generate_badge "$badge_label" "blue"))](${download_url})"
            revpack_rows+="| 🎁 Bundle | v${APP_VERSION:-N/A} | 🌐 All | ${size} | ${download_badge} |\n"
        done
        if [[ -n "$revpack_rows" ]]; then
            output+="### $(get_app_logo RevPack) — All-in-One Bundle\n\n"
            output+="> Contains all patched Magisk/KernelSU module zips in a single flashable archive.\n\n"
            output+="| Type | Version | Architecture | Size | Download |\n"
            output+="|:----:|:-------:|:------------:|:----:|:--------:|\n"
            output+="${revpack_rows}"
            output+="\n"
        fi
    fi

    if [[ ${#custom_revpack_entries[@]} -gt 0 ]]; then
        local sorted_customs=()
        while IFS= read -r _cl; do
            sorted_customs+=("$_cl")
        done < <(printf '%s\n' "${custom_revpack_entries[@]}" | sort -r | head -3)
        local custom_rows=""
        for _c in "${sorted_customs[@]}"; do
            [[ -z "$_c" ]] && continue
            local cfn csz curl ts_label="—"
            cfn=$(echo "$_c" | awk -F'\|\|\|' '{print $1}')
            csz=$(echo "$_c" | awk -F'\|\|\|' '{print $2}')
            curl=$(echo "$_c" | awk -F'\|\|\|' '{print $3}')
            if [[ "$cfn" =~ -custom-([0-9]{12}) ]]; then
                local raw="${BASH_REMATCH[1]}"
                ts_label="${raw:0:4}-${raw:4:2}-${raw:6:2} ${raw:8:2}:${raw:10:2}"
            fi
            local cbadge="[![Download]($(generate_badge "⬇_Download" "7C4DFF"))](${curl})"
            custom_rows+="| 🎨 Custom | ${ts_label} | 🌐 All | ${csz} | ${cbadge} |\n"
        done
        if [[ -n "$custom_rows" ]]; then
            output+="### 🎨 RevPack — Custom Builds *(latest 3)*\n\n"
            output+="> Built via [RevPack Configurator](https://thunderkex.github.io/revanced-extended/). Preserved alongside standard builds.\n\n"
            output+="| Type | Built | Architecture | Size | Download |\n"
            output+="|:----:|:-----:|:------------:|:----:|:--------:|\n"
            output+="${custom_rows}"
            output+="\n"
        fi
    fi

    if [[ -n "${app_files[RevPack]+x}" ]] || [[ ${#custom_revpack_entries[@]} -gt 0 ]]; then
        output+="---\n\n"
    fi

    for app in "${apps_order[@]}"; do
        [[ "$app" == "RevPack" ]] && continue
        local app_logo
        app_logo=$(get_app_logo "$app")
        local app_rows=""

        IFS='|' read -ra _entries <<< "${app_files[$app]}"
        for _entry in "${_entries[@]}"; do
            [[ -z "$_entry" ]] && continue

            local filename size download_url

            if [[ "$_entry" == local:* ]]; then
                local file="${_entry#local:}"
                [[ -f "$file" ]] || continue
                filename=$(basename "$file")
                parse_filename "$filename"
                size=$(get_file_size "$file")
                download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            elif [[ "$_entry" == release:* ]]; then
                local _rdata="${_entry#release:}"
                filename=$(echo "$_rdata" | awk -F'\|\|\|' '{print $1}')
                size=$(echo    "$_rdata" | awk -F'\|\|\|' '{print $2}')
                download_url=$(echo "$_rdata" | awk -F'\|\|\|' '{print $3}')
                parse_filename "$filename"
            else
                continue
            fi

            [[ -z "$download_url" ]] && continue

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
                    type_display="📦 APK"
                fi
            fi

            local badge_label
            badge_label=$(echo "⬇_Download" | sed 's/ /_/g')
            local download_badge="[![Download]($(generate_badge "$badge_label" "blue"))](${download_url})"

            app_rows+="| ${type_display} | v${APP_VERSION:-N/A} | ${arch_display} | ${size} | ${download_badge} |\n"
        done

        [[ -z "$app_rows" ]] && continue

        output+="### ${app_logo}\n\n"
        output+="| Type | Version | Architecture | Size | Download |\n"
        output+="|:----:|:-------:|:------------:|:----:|:--------:|\n"
        output+="${app_rows}"
        output+="\n"
    done
    
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
    
    output+="---\n\n"
    output+="<sub>📝 This section is automatically generated after each successful build.</sub>\n"
    
    echo -e "$output"
}

generate_downloads_md() {
    local repo_url="$1"
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    cat << EOF
### 📥 Available APKs

> **Last Updated:** ${build_date}

EOF
    
    declare -A app_files
    declare -A _seen_filenames
    local apps_order=()
    local custom_revpack_entries=()

    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file")
        if [[ "$filename" == *"-custom-"*.zip ]]; then
            local _lfsize _lfurl
            _lfsize=$(get_file_size "$file")
            _lfurl="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            custom_revpack_entries+=("${filename}|||${_lfsize}|||${_lfurl}")
            _seen_filenames["$filename"]=1
            continue
        fi
        parse_filename "$filename"
        _seen_filenames["$filename"]=1

        if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
            apps_order+=("$APP_NAME")
        fi
        app_files["$APP_NAME"]+="local:${file}|"
    done

    if [[ "${USE_RELEASE_ASSETS:-false}" == "true" ]]; then
        local _release_lines
        _release_lines=$(fetch_release_assets 2>/dev/null) || _release_lines=""
        while IFS= read -r _line; do
            [[ -z "$_line" ]] && continue
            local _rname _rsize _rurl
            _rname=$(echo "$_line" | awk -F'\|\|\|' '{print $1}')
            _rsize=$(echo "$_line" | awk -F'\|\|\|' '{print $2}')
            _rurl=$(echo  "$_line" | awk -F'\|\|\|' '{print $3}')
            [[ -n "${_seen_filenames[$_rname]+x}" ]] && continue
            if [[ "$_rname" == *"-custom-"*.zip ]]; then
                custom_revpack_entries+=("${_rname}|||${_rsize}|||${_rurl}")
                continue
            fi
            parse_filename "$_rname"
            if [[ -z "${app_files[$APP_NAME]+x}" ]]; then
                apps_order+=("$APP_NAME")
            fi
            app_files["$APP_NAME"]+="release:${_rname}|||${_rsize}|||${_rurl}|"
        done <<< "$_release_lines"
    fi

    if [[ -n "${app_files[RevPack]+x}" ]]; then
        local revpack_rows=""
        IFS='|' read -ra _entries <<< "${app_files[RevPack]}"
        for _entry in "${_entries[@]}"; do
            [[ -z "$_entry" ]] && continue
            local filename size download_url
            if [[ "$_entry" == local:* ]]; then
                local file="${_entry#local:}"
                [[ -f "$file" ]] || continue
                filename=$(basename "$file")
                parse_filename "$filename"
                size=$(get_file_size "$file")
                download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            elif [[ "$_entry" == release:* ]]; then
                local _rdata="${_entry#release:}"
                filename=$(echo "$_rdata" | awk -F'\|\|\|' '{print $1}')
                size=$(echo    "$_rdata" | awk -F'\|\|\|' '{print $2}')
                download_url=$(echo "$_rdata" | awk -F'\|\|\|' '{print $3}')
                parse_filename "$filename"
            else
                continue
            fi
            [[ -z "$download_url" ]] && continue
            local download_badge="[![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](${download_url})"
            revpack_rows+="| 🎁 Bundle | v${APP_VERSION:-N/A} | 🌐 All | ${size} | ${download_badge} |\n"
        done
        if [[ -n "$revpack_rows" ]]; then
            echo "### $(get_app_logo RevPack) — All-in-One Bundle"
            echo ""
            echo "> Contains all patched Magisk/KernelSU module zips in a single flashable archive."
            echo ""
            echo "| Type | Version | Architecture | Size | Download |"
            echo "|:----:|:-------:|:------------:|:----:|:--------:|"
            echo -e "${revpack_rows}"
        fi
    fi

    if [[ ${#custom_revpack_entries[@]} -gt 0 ]]; then
        local sorted_customs=()
        while IFS= read -r _cl; do
            sorted_customs+=("$_cl")
        done < <(printf '%s\n' "${custom_revpack_entries[@]}" | sort -r | head -3)
        local custom_rows=""
        for _c in "${sorted_customs[@]}"; do
            [[ -z "$_c" ]] && continue
            local cfn csz curl ts_label="—"
            cfn=$(echo "$_c" | awk -F'\|\|\|' '{print $1}')
            csz=$(echo "$_c" | awk -F'\|\|\|' '{print $2}')
            curl=$(echo "$_c" | awk -F'\|\|\|' '{print $3}')
            if [[ "$cfn" =~ -custom-([0-9]{12}) ]]; then
                local raw="${BASH_REMATCH[1]}"
                ts_label="${raw:0:4}-${raw:4:2}-${raw:6:2} ${raw:8:2}:${raw:10:2}"
            fi
            local cbadge="[![Download](https://img.shields.io/badge/⬇_Download-7C4DFF?style=flat-square)](${curl})"
            custom_rows+="| 🎨 Custom | ${ts_label} | 🌐 All | ${csz} | ${cbadge} |\n"
        done
        if [[ -n "$custom_rows" ]]; then
            echo "### 🎨 RevPack — Custom Builds *(latest 3)*"
            echo ""
            echo "> Built via RevPack Configurator. Preserved alongside standard builds."
            echo ""
            echo "| Type | Built | Architecture | Size | Download |"
            echo "|:----:|:-----:|:------------:|:----:|:--------:|"
            echo -e "${custom_rows}"
        fi
    fi

    if [[ -n "${app_files[RevPack]+x}" ]] || [[ ${#custom_revpack_entries[@]} -gt 0 ]]; then
        echo "---"
        echo ""
    fi

    for app in "${apps_order[@]}"; do
        [[ "$app" == "RevPack" ]] && continue
        local app_logo
        app_logo=$(get_app_logo "$app")
        local app_rows=""

        IFS='|' read -ra _entries <<< "${app_files[$app]}"
        for _entry in "${_entries[@]}"; do
            [[ -z "$_entry" ]] && continue

            local filename size download_url

            if [[ "$_entry" == local:* ]]; then
                local file="${_entry#local:}"
                [[ -f "$file" ]] || continue
                filename=$(basename "$file")
                parse_filename "$filename"
                size=$(get_file_size "$file")
                download_url="${repo_url}/releases/download/${RELEASE_TAG}/${filename}"
            elif [[ "$_entry" == release:* ]]; then
                local _rdata="${_entry#release:}"
                filename=$(echo "$_rdata" | awk -F'\|\|\|' '{print $1}')
                size=$(echo    "$_rdata" | awk -F'\|\|\|' '{print $2}')
                download_url=$(echo "$_rdata" | awk -F'\|\|\|' '{print $3}')
                parse_filename "$filename"
            else
                continue
            fi

            [[ -z "$download_url" ]] && continue

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
                    type_display="📦 APK"
                fi
            fi

            local download_badge="[![Download](https://img.shields.io/badge/⬇_Download-blue?style=flat-square)](${download_url})"
            app_rows+="| ${type_display} | v${APP_VERSION:-N/A} | ${arch_display} | ${size} | ${download_badge} |\n"
        done

        [[ -z "$app_rows" ]] && continue

        echo "### ${app_logo}"
        echo ""
        echo "| Type | Version | Architecture | Size | Download |"
        echo "|:----:|:-------:|:------------:|:----:|:--------:|"
        echo -e "${app_rows}"
    done
}

update_readme() {
    local repo_url="$1"
    local downloads_content
    downloads_content=$(generate_downloads_section "$repo_url")
    
    if [[ ! -f "$README_FILE" ]]; then
        warn "README.md not found, creating new file"
        echo -e "$downloads_content" > "$README_FILE"
        return
    fi
    
    local start_marker="<!-- DOWNLOADS_START -->"
    local end_marker="<!-- DOWNLOADS_END -->"
    
    if grep -q "$start_marker" "$README_FILE" && grep -q "$end_marker" "$README_FILE"; then
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
        {
            echo ""
            echo "$start_marker"
            echo -e "$downloads_content"
            echo "$end_marker"
        } >> "$README_FILE"
        log "Appended downloads section to README.md"
    fi
}

main() {
    log "Generating downloads documentation..."
    
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
    
    log "Generating DOWNLOADS.md..."
    generate_downloads_md "$repo_url" > "$DOWNLOADS_MD"
    log "Created: $DOWNLOADS_MD"
    
    log "Updating README.md..."
    update_readme "$repo_url"
    
    log "Done!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
