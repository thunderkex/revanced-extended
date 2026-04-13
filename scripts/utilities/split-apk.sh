#!/usr/bin/env bash
# ============================================
# APK Architecture Splitter
# Splits universal APKs into architecture-specific variants
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-build}"
TEMP_DIR="${TEMP_DIR:-temp}"
APKEDITOR_JAR="${TEMP_DIR}/apkeditor.jar"
APKEDITOR_URL="https://github.com/REAndroid/APKEditor/releases/download/V1.4.2/APKEditor-1.4.2.jar"

curl_progress_opts() {
    if [ -t 2 ] || [ "${GITHUB_ACTIONS-}" = "true" ]; then
        echo "--progress-bar"
    else
        echo "-sS"
    fi
}

# Supported architectures
ARCHITECTURES=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
epr() { echo -e "\033[0;31m[-] ${1}\033[0m" >&2; }

download_apkeditor() {
    if [ ! -f "$APKEDITOR_JAR" ]; then
        pr "Downloading APKEditor..."
        mkdir -p "$(dirname "$APKEDITOR_JAR")"
        curl $(curl_progress_opts) -L "$APKEDITOR_URL" -o "$APKEDITOR_JAR" || {
            epr "Failed to download APKEditor"
            return 1
        }
    fi
}

# Extract specific architecture from APK
split_apk_arch() {
    local input_apk="$1"
    local target_arch="$2"
    local output_apk="$3"
    
    pr "Splitting '$input_apk' for $target_arch..."
    
    local work_dir
    work_dir=$(mktemp -d -p "$TEMP_DIR")
    
    # Extract APK
    unzip -q "$input_apk" -d "$work_dir" || {
        epr "Failed to extract APK"
        rm -rf "$work_dir"
        return 1
    }
    
    # Remove other architectures from lib folder
    if [ -d "$work_dir/lib" ]; then
        for arch_dir in "$work_dir/lib"/*; do
            local arch_name
            arch_name=$(basename "$arch_dir")
            if [ "$arch_name" != "$target_arch" ] && [ -d "$arch_dir" ]; then
                rm -rf "$arch_dir"
            fi
        done
        
        # Check if target arch exists
        if [ ! -d "$work_dir/lib/$target_arch" ]; then
            epr "Architecture $target_arch not found in APK"
            rm -rf "$work_dir"
            return 1
        fi
    fi
    
    # Repack APK
    (
        cd "$work_dir"
        zip -q -r "$output_apk" .
    )
    
    rm -rf "$work_dir"
    pr "Created: $output_apk"
}

# Split all universal APKs in build directory
split_all_apks() {
    local target_archs=("${@:-${ARCHITECTURES[@]}}")
    
    download_apkeditor
    
    for apk in "$BUILD_DIR"/*.apk; do
        [ -f "$apk" ] || continue
        
        local filename
        filename=$(basename "$apk")
        
        # Skip already split APKs
        for arch in "${ARCHITECTURES[@]}"; do
            [[ "$filename" == *"$arch"* ]] && continue 2
        done
        
        local base_name="${filename%.apk}"
        
        for arch in "${target_archs[@]}"; do
            local output="${BUILD_DIR}/${base_name}-${arch}.apk"
            if split_apk_arch "$apk" "$arch" "$output"; then
                pr "Successfully split for $arch"
            else
                epr "Failed to split for $arch"
            fi
        done
    done
}

# Main entry point
main() {
    case "${1:-all}" in
        all)
            split_all_apks
            ;;
        arm64|arm64-v8a)
            split_all_apks "arm64-v8a"
            ;;
        arm|armeabi-v7a)
            split_all_apks "armeabi-v7a"
            ;;
        x64|x86_64)
            split_all_apks "x86_64"
            ;;
        x86)
            split_all_apks "x86"
            ;;
        help|--help|-h)
            echo "Usage: $0 [all|arm64|arm|x64|x86]"
            echo "  Splits universal APKs into architecture-specific variants"
            ;;
        *)
            epr "Unknown architecture: $1"
            exit 1
            ;;
    esac
}

main "$@"
