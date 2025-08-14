#!/usr/bin/env bash
# =============================================================================
# ReVanced Extended Builder
# Modern, structured build system for ReVanced modules and APKs
# =============================================================================

set -euo pipefail
shopt -s nullglob

# -----------------------------------------------------------------------------
# Script Configuration
# -----------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# Cleanup on exit or interrupt
cleanup() {
    local exit_code=$?
    pr "🧹 Cleaning up temporary files..."
    rm -rf temp/*tmp.* temp/*/*tmp.* temp/*-temporary-files 2>/dev/null || true
    exit $exit_code
}
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# Command Line Interface
# -----------------------------------------------------------------------------
show_help() {
    cat << EOF
ReVanced Extended Builder

USAGE:
    $SCRIPT_NAME [CONFIG_FILE] [OPTIONS]

ARGUMENTS:
    CONFIG_FILE         Configuration file (default: config.toml)

OPTIONS:
    clean               Clean all build artifacts and temporary files
    --config-update     Check for configuration updates and exit
    --help, -h          Show this help message

EXAMPLES:
    $SCRIPT_NAME                    # Build with default config
    $SCRIPT_NAME config.json        # Build with custom config
    $SCRIPT_NAME clean              # Clean build environment
    $SCRIPT_NAME --config-update    # Check for updates

EOF
}

# Handle command line arguments
case "${1:-}" in
    "clean")
        pr "🧹 Cleaning build environment..."
        rm -rf temp build logs build.md
        pr "✅ Clean completed"
        exit 0
        ;;
    "--help"|"-h")
        show_help
        exit 0
        ;;
esac

# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------
source utils.sh

# Validate required dependencies
validate_dependencies() {
    local missing=()
    
    jq --version >/dev/null 2>&1 || missing+=("jq")
    java --version >/dev/null 2>&1 || missing+=("java")
    zip --version >/dev/null 2>&1 || missing+=("zip")
    
    if [ ${#missing[@]} -gt 0 ]; then
        abort "Missing required dependencies: ${missing[*]}\nInstall with: apt install ${missing[*]// / } or equivalent"
    fi
}

validate_dependencies
set_prebuilts

# Validation helper
validate_boolean() { 
    if ! isoneof "${1}" "true" "false"; then 
        abort "ERROR: '${1}' is not a valid option for '${2}': only true or false is allowed"
    fi
}

# -----------------------------------------------------------------------------
# Configuration Loading and Validation
# -----------------------------------------------------------------------------
load_config() {
    local config_file="${1:-config.toml}"
    
    if ! toml_prep "$config_file"; then
        abort "could not find config file '$config_file'\n\tUsage: $SCRIPT_NAME <config.toml>"
    fi
    
    pr "📋 Loading configuration from: $config_file"
    
    local main_config_t
    main_config_t=$(toml_get_table_main)
    
    # Load main configuration with defaults
    COMPRESSION_LEVEL=$(toml_get "$main_config_t" compression-level) || COMPRESSION_LEVEL="9"
    
    if ! PARALLEL_JOBS=$(toml_get "$main_config_t" parallel-jobs); then
        if [ "$OS" = Android ]; then 
            PARALLEL_JOBS=1
        else 
            PARALLEL_JOBS=$(nproc)
        fi
    fi
    
    REMOVE_RV_INTEGRATIONS_CHECKS=$(toml_get "$main_config_t" remove-rv-integrations-checks) || REMOVE_RV_INTEGRATIONS_CHECKS="true"
    DEF_PATCHES_VER=$(toml_get "$main_config_t" patches-version) || DEF_PATCHES_VER="latest"
    DEF_CLI_VER=$(toml_get "$main_config_t" cli-version) || DEF_CLI_VER="latest"
    DEF_PATCHES_SRC=$(toml_get "$main_config_t" patches-source) || DEF_PATCHES_SRC="ReVanced/revanced-patches"
    DEF_CLI_SRC=$(toml_get "$main_config_t" cli-source) || DEF_CLI_SRC="j-hc/revanced-cli"
    DEF_RV_BRAND=$(toml_get "$main_config_t" rv-brand) || DEF_RV_BRAND="ReVanced"
    
    # Validate configuration
    if ((COMPRESSION_LEVEL > 9)) || ((COMPRESSION_LEVEL < 0)); then 
        abort "compression-level must be within 0-9"
    fi
    
    pr "⚙️  Configuration loaded successfully"
    pr "   - Parallel jobs: $PARALLEL_JOBS"
    pr "   - Compression level: $COMPRESSION_LEVEL"
    pr "   - Default patches source: $DEF_PATCHES_SRC"
}

# -----------------------------------------------------------------------------
# Environment Initialization
# -----------------------------------------------------------------------------
initialize_environment() {
    pr "🚀 Initializing build environment..."
    
    # Create necessary directories
    mkdir -p "$TEMP_DIR" "$BUILD_DIR"
    
    # Initialize build log
    : >build.md
    
    # Configure Magisk updates (main_config_t is available from load_config)
    local main_config_t
    main_config_t=$(toml_get_table_main)
    ENABLE_MAGISK_UPDATE=$(toml_get "$main_config_t" enable-magisk-update) || ENABLE_MAGISK_UPDATE=true
    if [ "$ENABLE_MAGISK_UPDATE" = true ] && [ -z "${GITHUB_REPOSITORY-}" ]; then
        pr "⚠️  Building locally. Magisk updates will not be enabled."
        ENABLE_MAGISK_UPDATE=false
    fi
    
    # Clean up previous builds
    rm -rf revanced-magisk/bin/*/tmp.*
    if [ -n "$(find "$TEMP_DIR" -name "*-rv" -type d 2>/dev/null)" ]; then
        find "$TEMP_DIR" -name "*-rv" -type d -exec sh -c 'touch "$1/changelog.md"' _ {} \; 2>/dev/null || :
    fi
    
    # Download compression binaries
    download_compression_binaries
    
    pr "✅ Environment initialized"
}

download_compression_binaries() {
    pr "📦 Downloading compression binaries..."
    
    local bin_dirs=("arm64" "arm" "x86" "x64")
    local architectures=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")
    
    for i in "${!bin_dirs[@]}"; do
        local bin_dir="${MODULE_TEMPLATE_DIR}/bin/${bin_dirs[i]}"
        local arch="${architectures[i]}"
        
        mkdir -p "$bin_dir"
        gh_dl "$bin_dir/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-$arch"
    done
}

# -----------------------------------------------------------------------------
# Build Processing Functions
# -----------------------------------------------------------------------------
process_app_configuration() {
    local table_name="$1"
    local t="$2"
    
    declare -A app_args
    
    # Load source configurations
    app_args[patches_src]=$(toml_get "$t" patches-source) || app_args[patches_src]=$DEF_PATCHES_SRC
    app_args[patches_ver]=$(toml_get "$t" patches-version) || app_args[patches_ver]=$DEF_PATCHES_VER
    app_args[cli_src]=$(toml_get "$t" cli-source) || app_args[cli_src]=$DEF_CLI_SRC
    app_args[cli_ver]=$(toml_get "$t" cli-version) || app_args[cli_ver]=$DEF_CLI_VER
    
    # Get prebuilts
    if ! RVP="$(get_rv_prebuilts "${app_args[cli_src]}" "${app_args[cli_ver]}" "${app_args[patches_src]}" "${app_args[patches_ver]}")"; then
        abort "could not download rv prebuilts"
    fi
    
    read -r rv_cli_jar rv_patches_jar <<<"$RVP"
    app_args[cli]=$rv_cli_jar
    app_args[ptjar]=$rv_patches_jar
    
    # Check riplib capability
    if [[ -v cliriplib[${app_args[cli]}] ]]; then 
        app_args[riplib]=${cliriplib[${app_args[cli]}]}
    else
        if [[ $(java -jar "${app_args[cli]}" patch 2>&1) == *rip-lib* ]]; then
            cliriplib[${app_args[cli]}]=true
            app_args[riplib]=true
        else
            cliriplib[${app_args[cli]}]=false
            app_args[riplib]=false
        fi
    fi
    
    if [ "${app_args[riplib]}" = "true" ] && [ "$(toml_get "$t" riplib)" = "false" ]; then 
        app_args[riplib]=false
    fi
    
    # Load app-specific configurations
    load_app_settings "$t" "app_args" "$table_name"
    
    echo "$(declare -p app_args)"
}

load_app_settings() {
    local t="$1"
    local app_args_name="$2"
    local table_name="$3"
    
    # Set values in the associative array using safer eval approach
    local rv_brand excluded_patches included_patches exclusive_patches version app_name patcher_args
    
    rv_brand=$(toml_get "$t" rv-brand) || rv_brand="$DEF_RV_BRAND"
    eval "${app_args_name}[rv_brand]=\"\$rv_brand\""
    
    excluded_patches=$(toml_get "$t" excluded-patches) || excluded_patches=""
    eval "${app_args_name}[excluded_patches]=\"\$excluded_patches\""
    
    included_patches=$(toml_get "$t" included-patches) || included_patches=""
    eval "${app_args_name}[included_patches]=\"\$included_patches\""
    
    exclusive_patches=$(toml_get "$t" exclusive-patches) || exclusive_patches="false"
    eval "${app_args_name}[exclusive_patches]=\"\$exclusive_patches\""
    
    version=$(toml_get "$t" version) || version="auto"
    eval "${app_args_name}[version]=\"\$version\""
    
    app_name=$(toml_get "$t" app-name) || app_name="$table_name"
    eval "${app_args_name}[app_name]=\"\$app_name\""
    
    patcher_args=$(toml_get "$t" patcher-args) || patcher_args=""
    eval "${app_args_name}[patcher_args]=\"\$patcher_args\""
    
    eval "${app_args_name}[table]=\"\$table_name\""
    
    # Validate patches format
    if [ -n "$excluded_patches" ] && [[ $excluded_patches != *'"'* ]]; then 
        abort "patch names inside excluded-patches must be quoted"
    fi
    if [ -n "$included_patches" ] && [[ $included_patches != *'"'* ]]; then 
        abort "patch names inside included-patches must be quoted"
    fi
    
    validate_boolean "$exclusive_patches" "exclusive-patches"
    
    # Build mode validation
    local build_mode
    build_mode=$(toml_get "$t" build-mode) || build_mode="apk"
    eval "${app_args_name}[build_mode]=\"\$build_mode\""
    if ! isoneof "$build_mode" both apk module; then
        abort "ERROR: build-mode '$build_mode' is not a valid option for '$table_name': only 'both', 'apk' or 'module' is allowed"
    fi
    
    # Download source configurations
    load_download_sources "$t" "$app_args_name" "$table_name"
    
    # Architecture and module configurations
    local arch include_stock dpi module_prop_name
    arch=$(toml_get "$t" arch) || arch="all"
    eval "${app_args_name}[arch]=\"\$arch\""
    validate_architecture "$arch" "$table_name"
    
    include_stock=$(toml_get "$t" include-stock) || include_stock="true"
    eval "${app_args_name}[include_stock]=\"\$include_stock\""
    validate_boolean "$include_stock" "include-stock"
    
    dpi=$(toml_get "$t" apkmirror-dpi) || dpi="nodpi"
    eval "${app_args_name}[dpi]=\"\$dpi\""
    
    local table_name_f=${table_name,,}
    table_name_f=${table_name_f// /-}
    module_prop_name=$(toml_get "$t" module-prop-name) || module_prop_name="${table_name_f}-jhc"
    eval "${app_args_name}[module_prop_name]=\"\$module_prop_name\""
}

load_download_sources() {
    local t="$1"
    local app_args_name="$2"
    local table_name="$3"
    
    # Initialize download sources with default empty values
    eval "${app_args_name}[uptodown_dlurl]=\"\""
    eval "${app_args_name}[apkmirror_dlurl]=\"\""
    eval "${app_args_name}[archive_dlurl]=\"\""
    eval "${app_args_name}[dl_from]=\"\""
    
    # Check uptodown source
    local uptodown_dlurl
    if uptodown_dlurl=$(toml_get "$t" uptodown-dlurl); then
        uptodown_dlurl=${uptodown_dlurl%/}
        uptodown_dlurl=${uptodown_dlurl%download}
        uptodown_dlurl=${uptodown_dlurl%/}
        eval "${app_args_name}[uptodown_dlurl]=\"\$uptodown_dlurl\""
        eval "${app_args_name}[dl_from]=\"uptodown\""
    fi
    
    # Check apkmirror source
    local apkmirror_dlurl
    if apkmirror_dlurl=$(toml_get "$t" apkmirror-dlurl); then
        apkmirror_dlurl=${apkmirror_dlurl%/}
        eval "${app_args_name}[apkmirror_dlurl]=\"\$apkmirror_dlurl\""
        eval "${app_args_name}[dl_from]=\"apkmirror\""
    fi
    
    # Check archive source
    local archive_dlurl
    if archive_dlurl=$(toml_get "$t" archive-dlurl); then
        archive_dlurl=${archive_dlurl%/}
        eval "${app_args_name}[archive_dlurl]=\"\$archive_dlurl\""
        eval "${app_args_name}[dl_from]=\"archive\""
    fi
    
    # Check if at least one download source is configured
    local dl_from
    eval "dl_from=\${${app_args_name}[dl_from]}"
    if [ -z "$dl_from" ]; then 
        abort "ERROR: no 'apkmirror_dlurl', 'uptodown_dlurl' or 'archive_dlurl' option was set for '$table_name'."
    fi
}

validate_architecture() {
    local arch="$1"
    local table_name="$2"
    
    if [ "$arch" != "both" ] && [ "$arch" != "all" ] && [[ $arch != "arm64-v8a"* ]] && [[ $arch != "arm-v7a"* ]]; then
        abort "wrong arch '$arch' for '$table_name'"
    fi
}
# -----------------------------------------------------------------------------
# Main Build Loop
# -----------------------------------------------------------------------------
run_build() {
    local config_file="${1:-config.toml}"
    
    # Handle special commands
    if [ "${2:-}" = "--config-update" ]; then
        config_update
        exit 0
    fi
    
    # Load configuration and initialize environment
    load_config "$config_file"
    initialize_environment
    
    # Process builds
    declare -A cliriplib
    local idx=0
    
    pr "🔄 Starting build process..."
    
    for table_name in $(toml_get_table_names); do
        if [ -z "$table_name" ]; then continue; fi
        
        local t enabled
        t=$(toml_get_table "$table_name")
        enabled=$(toml_get "$t" enabled) || enabled=true
        validate_boolean "$enabled" "enabled"
        
        if [ "$enabled" = false ]; then
            pr "⏭️  Skipping disabled: $table_name"
            continue
        fi
        
        # Manage parallel job limit
        if ((idx >= PARALLEL_JOBS)); then
            wait -n
            idx=$((idx - 1))
        fi
        
        pr "🔧 Processing: $table_name"
        
        # Process app configuration
        local app_config
        app_config=$(process_app_configuration "$table_name" "$t")
        
        # Handle architecture splitting
        eval "$app_config"
        if [ "${app_args[arch]}" = both ]; then
            process_dual_architecture "$table_name" "$app_config" "idx"
        else
            process_single_architecture "$table_name" "$app_config" "idx"
        fi
    done
    
    wait
    cleanup_and_finalize
}

process_dual_architecture() {
    local table_name="$1"
    local app_config="$2"
    local idx_var="$3"
    
    # ARM64 build
    eval "$app_config"
    app_args[table]="$table_name (arm64-v8a)"
    app_args[arch]="arm64-v8a"
    local module_prop_name_b=${app_args[module_prop_name]}
    app_args[module_prop_name]="${module_prop_name_b}-arm64"
    eval "$idx_var=\$((\$$idx_var + 1))"
    build_rv "$(declare -p app_args)" &
    
    # ARM32 build
    eval "$app_config"
    app_args[table]="$table_name (arm-v7a)"
    app_args[arch]="arm-v7a"
    app_args[module_prop_name]="${module_prop_name_b}-arm"
    
    local current_idx
    eval "current_idx=\$$idx_var"
    if ((current_idx >= PARALLEL_JOBS)); then
        wait -n
        eval "$idx_var=\$((\$$idx_var - 1))"
    fi
    eval "$idx_var=\$((\$$idx_var + 1))"
    build_rv "$(declare -p app_args)" &
}

process_single_architecture() {
    local table_name="$1"
    local app_config="$2"
    local idx_var="$3"
    
    eval "$app_config"
    
    # Adjust module prop name for specific architectures
    if [ "${app_args[arch]}" = "arm64-v8a" ]; then
        app_args[module_prop_name]="${app_args[module_prop_name]}-arm64"
    elif [ "${app_args[arch]}" = "arm-v7a" ]; then
        app_args[module_prop_name]="${app_args[module_prop_name]}-arm"
    fi
    
    eval "$idx_var=\$((\$$idx_var + 1))"
    build_rv "$(declare -p app_args)" &
}

cleanup_and_finalize() {
    pr "🧹 Cleaning up temporary files..."
    rm -rf temp/tmp.*
    
    if [ -z "$(ls -A1 "${BUILD_DIR}")" ]; then 
        abort "❌ All builds failed."
    fi
    
    pr "📝 Generating build summary..."
    
    # Add standard information to build log
    log "\n📱 **Installation Instructions:**"
    log "- Install [MicroG-RE](https://github.com/WSTxda/MicroG-RE/releases) for non-root YouTube and YT Music APKs"
    log "- Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) module to detach patched apps from being updated by Play Store\n"
    
    # Add changelog information
    if [ -n "$(find "$TEMP_DIR" -name "*-rv" -type d 2>/dev/null)" ]; then
        find "$TEMP_DIR" -name "*-rv" -type d -exec sh -c 'if [ -f "$1/changelog.md" ]; then cat "$1/changelog.md"; fi' _ {} \; | head -1 | {
            read -r first_line
            if [ -n "$first_line" ]; then
                find "$TEMP_DIR" -name "*-rv" -type d -exec cat {}/changelog.md \; 2>/dev/null | log
            fi
        }
    fi
    
    # Add skipped items if any
    local skipped
    skipped=$(cat "$TEMP_DIR"/skipped 2>/dev/null | sort -u || :)
    if [ -n "$skipped" ]; then
        log "\n⏭️ **Skipped:**"
        log "$skipped"
    fi
    
    pr "✅ Build process completed successfully!"
}

# -----------------------------------------------------------------------------
# Script Entry Point
# -----------------------------------------------------------------------------
main() {
    run_build "$@"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
