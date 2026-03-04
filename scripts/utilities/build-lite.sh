#!/usr/bin/env bash
# ============================================
# Lite APK & Module Builder
# Creates resource-stripped "lite" versions of APKs and Magisk modules
# Removes unused languages/DPIs for smaller file size
# 
# Configuration via environment variables (set from config.toml):
#   LITE_LANGUAGES     - Languages to keep (default: en)
#   LITE_DPI           - DPIs to keep (default: xxhdpi,xxxhdpi,nodpi)
#   LITE_BUILD_MODULES - Build lite modules too (default: true)
#   LITE_COMPRESSION   - Compression level 0-9 (default: 9)
#   BUILD_DIR          - Build output directory (default: build)
#   TEMP_DIR           - Temp directory (default: temp)
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-build}"
TEMP_DIR="${TEMP_DIR:-temp}"
APKEDITOR_JAR="${TEMP_DIR}/apkeditor.jar"
APKEDITOR_URL="https://github.com/REAndroid/APKEditor/releases/download/V1.4.2/APKEditor-1.4.2.jar"

# Configuration from environment (passed from config.toml via build.sh)
KEEP_LANGUAGES="${LITE_LANGUAGES:-en}"
KEEP_DPIS="${LITE_DPI:-xxhdpi,xxxhdpi,nodpi}"
BUILD_MODULES="${LITE_BUILD_MODULES:-true}"
COMPRESSION_LEVEL="${LITE_COMPRESSION:-9}"

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
epr() { echo -e "\033[0;31m[-] ${1}\033[0m" >&2; }

download_apkeditor() {
    if [ ! -f "$APKEDITOR_JAR" ]; then
        pr "Downloading APKEditor..."
        mkdir -p "$(dirname "$APKEDITOR_JAR")"
        curl -sL "$APKEDITOR_URL" -o "$APKEDITOR_JAR" || {
            epr "Failed to download APKEditor"
            return 1
        }
    fi
}

# Create lite version of APK
create_lite_apk() {
    local input_apk="$1"
    local output_apk="$2"
    local keep_langs="$3"
    local keep_dpis="$4"
    
    pr "Creating lite version of '$input_apk'..."
    
    local work_dir
    work_dir=$(mktemp -d -p "$TEMP_DIR")
    
    # Extract APK
    unzip -q "$input_apk" -d "$work_dir" || {
        epr "Failed to extract APK"
        rm -rf "$work_dir"
        return 1
    }
    
    local original_size
    original_size=$(du -sb "$work_dir" | cut -f1)
    
    # Process resources
    if [ -d "$work_dir/res" ]; then
        # Convert comma-separated to array
        IFS=',' read -ra LANGS <<< "$keep_langs"
        IFS=',' read -ra DPIS <<< "$keep_dpis"
        
        # Remove unwanted language resources
        for res_dir in "$work_dir/res"/values-*; do
            [ -d "$res_dir" ] || continue
            local dir_name
            dir_name=$(basename "$res_dir")
            
            # Check if it's a language folder
            if [[ "$dir_name" =~ ^values-[a-z]{2}(-r[A-Z]{2})?$ ]]; then
                local lang_code="${dir_name#values-}"
                lang_code="${lang_code%%-*}"
                
                local keep=false
                for lang in "${LANGS[@]}"; do
                    if [[ "$lang_code" == "$lang"* ]]; then
                        keep=true
                        break
                    fi
                done
                
                if [ "$keep" = false ]; then
                    rm -rf "$res_dir"
                fi
            fi
        done
        
        # Remove unwanted DPI resources
        for res_dir in "$work_dir/res"/drawable-* "$work_dir/res"/mipmap-*; do
            [ -d "$res_dir" ] || continue
            local dir_name
            dir_name=$(basename "$res_dir")
            
            # Extract DPI qualifier
            local dpi_match=false
            for dpi in "${DPIS[@]}"; do
                if [[ "$dir_name" == *"$dpi"* ]]; then
                    dpi_match=true
                    break
                fi
            done
            
            # Keep nodpi by default
            if [[ "$dir_name" == *"nodpi"* ]]; then
                dpi_match=true
            fi
            
            if [ "$dpi_match" = false ]; then
                rm -rf "$res_dir"
            fi
        done
    fi
    
    # Remove raw resources that are typically not needed
    local raw_removals=(
        "res/raw/keep.xml"
        "res/raw-*/"
    )
    
    for pattern in "${raw_removals[@]}"; do
        rm -rf "$work_dir"/$pattern 2>/dev/null || true
    done
    
    # Calculate size reduction
    local lite_size
    lite_size=$(du -sb "$work_dir" | cut -f1)
    local saved=$((original_size - lite_size))
    local saved_mb=$((saved / 1024 / 1024))
    
    # Repack APK - use absolute path since we cd into work_dir
    local output_dir
    output_dir="$(dirname "$output_apk")"
    mkdir -p "$output_dir"
    local abs_output_apk
    abs_output_apk="$(cd "$output_dir" && pwd)/$(basename "$output_apk")"
    (
        cd "$work_dir"
        zip -"${COMPRESSION_LEVEL}" -q -r "$abs_output_apk" .
    )
    
    rm -rf "$work_dir"
    
    local final_size
    final_size=$(du -sb "$output_apk" | cut -f1)
    local final_mb=$((final_size / 1024 / 1024))
    
    pr "Created lite APK: $output_apk (${final_mb}MB, saved ~${saved_mb}MB)"
}

# Create lite version of Magisk module from existing lite APK
create_lite_module() {
    local lite_apk="$1"
    local original_module="$2"
    local output_module="$3"
    
    pr "Creating lite module from '$lite_apk'..."
    
    if [ ! -f "$lite_apk" ]; then
        epr "Lite APK not found: $lite_apk"
        return 1
    fi
    
    if [ ! -f "$original_module" ]; then
        epr "Original module not found: $original_module"
        return 1
    fi
    
    local work_dir
    work_dir=$(mktemp -d -p "$TEMP_DIR")
    
    # Extract original module to get the structure (scripts, module.prop, etc.)
    unzip -q "$original_module" -d "$work_dir" || {
        epr "Failed to extract original module"
        rm -rf "$work_dir"
        return 1
    }
    
    # Replace base.apk with the lite APK
    if [ -f "$work_dir/base.apk" ]; then
        cp -f "$lite_apk" "$work_dir/base.apk"
    else
        epr "No base.apk found in original module"
        rm -rf "$work_dir"
        return 1
    fi
    
    # Update module.prop to indicate lite version
    if [ -f "$work_dir/module.prop" ]; then
        sed -i 's/^name=\(.*\)$/name=\1 (Lite)/' "$work_dir/module.prop"
        # Only add -lite suffix if not already present
        if ! grep -q "^id=.*-lite$" "$work_dir/module.prop"; then
            sed -i 's/^id=\(.*\)$/id=\1-lite/' "$work_dir/module.prop"
        fi
    fi
    
    # Repack module
    local output_dir
    output_dir="$(dirname "$output_module")"
    mkdir -p "$output_dir"
    local abs_output_module
    abs_output_module="$(cd "$output_dir" && pwd)/$(basename "$output_module")"
    
    (
        cd "$work_dir"
        zip -"${COMPRESSION_LEVEL}" -q -r "$abs_output_module" .
    )
    
    rm -rf "$work_dir"
    
    local final_size
    final_size=$(du -sb "$output_module" | cut -f1)
    local final_mb=$((final_size / 1024 / 1024))
    
    pr "Created lite module: $output_module (${final_mb}MB)"
}

# Process all APKs in build directory
build_all_lite() {
    download_apkeditor
    
    local apk_count=0
    local module_count=0
    
    pr "Lite build config: languages=$KEEP_LANGUAGES, dpi=$KEEP_DPIS, modules=$BUILD_MODULES, compression=$COMPRESSION_LEVEL"
    
    # First pass: Create lite APKs and track them
    declare -A lite_apks  # Map: original_base_name -> lite_apk_path
    
    for apk in "$BUILD_DIR"/*.apk; do
        [ -f "$apk" ] || continue
        
        local filename
        filename=$(basename "$apk")
        
        # Skip already-lite APKs and module APKs
        [[ "$filename" == *"-lite"* ]] && continue
        [[ "$filename" == *"-module"* ]] && continue
        
        local base_name="${filename%.apk}"
        local lite_apk="${BUILD_DIR}/${base_name}-lite.apk"
        
        if create_lite_apk "$apk" "$lite_apk" "$KEEP_LANGUAGES" "$KEEP_DPIS"; then
            ((++apk_count)) || true
            lite_apks["$base_name"]="$lite_apk"
        fi
    done
    
    # Second pass: Create lite modules using the lite APKs
    if [ "$BUILD_MODULES" = "true" ]; then
        for module in "$BUILD_DIR"/*.zip; do
            [ -f "$module" ] || continue
            
            local filename
            filename=$(basename "$module")
            
            # Skip already-lite modules
            [[ "$filename" == *"-lite"* ]] && continue
            
            # Try to find matching lite APK
            # Module naming: app-name-v1.0-arch-magisk.zip or similar
            # APK naming: app-name-v1.0-arch.apk
            local module_base="${filename%.zip}"
            local lite_module="${BUILD_DIR}/${module_base}-lite.zip"
            
            # Find the corresponding lite APK by matching patterns
            local found_lite_apk=""
            for apk_base in "${!lite_apks[@]}"; do
                # Check if module name contains the APK base name (without version suffixes)
                # e.g., module: music-ex-morphed-v8.30.54-arm64-v8a-magisk.zip
                #       apk:    music-ex-morphed-revanced-v8.30.54-arm64-v8a.apk
                if [[ "$module_base" == *"${apk_base%%-revanced*}"* ]] || \
                   [[ "$module_base" == *"${apk_base}"* ]] || \
                   [[ "${apk_base}" == *"${module_base%%-magisk*}"* ]]; then
                    found_lite_apk="${lite_apks[$apk_base]}"
                    break
                fi
            done
            
            # Alternative: match by extracting common identifiers
            if [ -z "$found_lite_apk" ]; then
                # Try matching by app name and version
                for apk_base in "${!lite_apks[@]}"; do
                    # Extract version pattern like v8.30.54
                    local version_pattern
                    version_pattern=$(echo "$module_base" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                    if [ -n "$version_pattern" ] && [[ "$apk_base" == *"$version_pattern"* ]]; then
                        # Also check architecture match
                        local arch_pattern
                        arch_pattern=$(echo "$module_base" | grep -oE '(arm64-v8a|armeabi-v7a|x86_64|x86)' | head -1)
                        if [ -n "$arch_pattern" ] && [[ "$apk_base" == *"$arch_pattern"* ]]; then
                            found_lite_apk="${lite_apks[$apk_base]}"
                            break
                        fi
                    fi
                done
            fi
            
            if [ -n "$found_lite_apk" ]; then
                if create_lite_module "$found_lite_apk" "$module" "$lite_module"; then
                    ((++module_count)) || true
                fi
            else
                pr "No matching lite APK found for module: $filename"
            fi
        done
    fi
    
    pr "Created $apk_count lite APK variants and $module_count lite module variants"
}

# Main entry point
main() {
    case "${1:-build}" in
        build)
            build_all_lite
            ;;
        single)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                epr "Usage: $0 single <input.apk> <output.apk>"
                exit 1
            fi
            create_lite_apk "$2" "$3" "$KEEP_LANGUAGES" "$KEEP_DPIS"
            ;;
        module)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                epr "Usage: $0 module <lite.apk> <original.zip> <output.zip>"
                exit 1
            fi
            create_lite_module "$2" "$3" "$4"
            ;;
        help|--help|-h)
            cat <<EOF
Usage: $0 [build|single <input> <output>|module <lite.apk> <orig.zip> <output>]

Commands:
  build                              Process all APKs and modules in BUILD_DIR
  single <in.apk> <out>              Create lite version of a single APK
  module <lite.apk> <orig.zip> <out> Create lite module using lite APK

Environment variables (configured via config.toml):
  LITE_LANGUAGES     Languages to keep (default: en)
  LITE_DPI           DPIs to keep (default: xxhdpi,xxxhdpi,nodpi)
  LITE_BUILD_MODULES Build lite modules too (default: true)
  LITE_COMPRESSION   Compression level 0-9 (default: 9)
  BUILD_DIR          Build output directory (default: build)
  TEMP_DIR           Temp directory (default: temp)

config.toml options:
  build-lite = true          # Enable lite builds
  lite-build-modules = true  # Also build lite modules
  lite-languages = "en"      # Languages to keep
  lite-dpi = "xxhdpi"        # DPIs to keep
  lite-compression = 9       # Compression level
  
Examples:
  LITE_LANGUAGES="en,es" ./build-lite.sh
  ./build-lite.sh single app.apk app-lite.apk
  ./build-lite.sh module app-lite.apk app-magisk.zip app-magisk-lite.zip
EOF
            ;;
        *)
            epr "Unknown command: $1"
            exit 1
            ;;
    esac
}

main "$@"
