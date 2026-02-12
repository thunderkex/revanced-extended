#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob
trap "rm -rf temp/*tmp.* temp/*/*tmp.* temp/*-temporary-files; exit 130" INT

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build state tracking
BUILD_STATE_FILE="temp/.build_state"
FAILED_BUILDS=()
SUCCESSFUL_BUILDS=()

pr() { echo -e "${GREEN}[+] ${1}${NC}"; }
warn() { echo -e "${YELLOW}[!] ${1}${NC}"; }
epr() { echo -e "${RED}[-] ${1}${NC}" >&2; }

# ============================================
# Pre-flight checks
# ============================================
check_dependencies() {
    local missing=()
    
    command -v jq >/dev/null || missing+=("jq")
    command -v java >/dev/null || missing+=("openjdk-17")
    command -v zip >/dev/null || missing+=("zip")
    command -v curl >/dev/null || missing+=("curl")
    
    if [ ${#missing[@]} -gt 0 ]; then
        epr "Missing dependencies: ${missing[*]}"
        epr "Install with: apt install ${missing[*]}"
        exit 1
    fi
    
    # Check Java version
    local java_ver
    java_ver=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$java_ver" -lt 17 ] 2>/dev/null; then
        warn "Java 17+ recommended, found version $java_ver"
    fi
}

check_disk_space() {
    local required_mb=2000  # 2GB minimum
    local available_mb
    
    if [ "$OS" = "Android" ]; then
        available_mb=$(df -m . | tail -1 | awk '{print $4}')
    else
        available_mb=$(df -BM . | tail -1 | awk '{print $4}' | tr -d 'M')
    fi
    
    if [ "$available_mb" -lt "$required_mb" ] 2>/dev/null; then
        warn "Low disk space: ${available_mb}MB available, ${required_mb}MB recommended"
    fi
}

check_network() {
    if ! curl -s --connect-timeout 5 https://api.github.com >/dev/null 2>&1; then
        warn "Network connectivity issues detected"
    fi
}

# Run pre-flight checks
preflight_checks() {
    pr "Running pre-flight checks..."
    check_dependencies
    check_disk_space
    check_network
}

if [ "${1-}" = "clean" ]; then
	rm -rf temp build logs build.md "$BUILD_STATE_FILE"
	exit 0
fi

source utils.sh

preflight_checks

set_prebuilts

vtf() { if ! isoneof "${1}" "true" "false"; then abort "ERROR: '${1}' is not a valid option for '${2}': only true or false is allowed"; fi; }

# ============================================
# Resume support
# ============================================
save_build_state() {
    local app_name="$1"
    local status="$2"
    echo "$app_name:$status" >> "$BUILD_STATE_FILE"
}

load_build_state() {
    local app_name="$1"
    if [ -f "$BUILD_STATE_FILE" ]; then
        grep "^${app_name}:completed$" "$BUILD_STATE_FILE" >/dev/null 2>&1
    else
        return 1
    fi
}

clear_build_state() {
    rm -f "$BUILD_STATE_FILE"
}

# ============================================
# Main configuration
# ============================================
toml_prep "${1:-config.toml}" || abort "could not find config file '${1:-config.toml}'\n\tUsage: $0 <config.toml>"
main_config_t=$(toml_get_table_main)
COMPRESSION_LEVEL=$(toml_get "$main_config_t" compression-level) || COMPRESSION_LEVEL="9"
if ! PARALLEL_JOBS=$(toml_get "$main_config_t" parallel-jobs); then
	if [ "$OS" = Android ]; then PARALLEL_JOBS=1; else PARALLEL_JOBS=$(nproc); fi
fi

# New config options
CONTINUE_ON_ERROR=$(toml_get "$main_config_t" continue-on-error) || CONTINUE_ON_ERROR="true"
DOWNLOAD_TIMEOUT=$(toml_get "$main_config_t" download-timeout) || DOWNLOAD_TIMEOUT="30"
DOWNLOAD_RETRIES=$(toml_get "$main_config_t" download-retries) || DOWNLOAD_RETRIES="3"
DEFAULT_ARCH=$(toml_get "$main_config_t" default-arch) || DEFAULT_ARCH="arm64-v8a"
BUILD_LITE=$(toml_get "$main_config_t" build-lite) || BUILD_LITE="false"
LITE_BUILD_MODULES=$(toml_get "$main_config_t" lite-build-modules) || LITE_BUILD_MODULES="true"
LITE_LANGUAGES=$(toml_get "$main_config_t" lite-languages) || LITE_LANGUAGES="en"
LITE_DPI=$(toml_get "$main_config_t" lite-dpi) || LITE_DPI="xxhdpi"
LITE_COMPRESSION=$(toml_get "$main_config_t" lite-compression) || LITE_COMPRESSION="9"

# Override from environment
DEFAULT_ARCH="${TARGET_ARCH:-$DEFAULT_ARCH}"
BUILD_LITE="${BUILD_LITE_ENV:-$BUILD_LITE}"

REMOVE_RV_INTEGRATIONS_CHECKS=$(toml_get "$main_config_t" remove-rv-integrations-checks) || REMOVE_RV_INTEGRATIONS_CHECKS="true"
DEF_PATCHES_VER=$(toml_get "$main_config_t" patches-version) || DEF_PATCHES_VER="latest"
DEF_CLI_VER=$(toml_get "$main_config_t" cli-version) || DEF_CLI_VER="latest"
DEF_PATCHES_SRC=$(toml_get "$main_config_t" patches-source) || DEF_PATCHES_SRC="ReVanced/revanced-patches"
DEF_CLI_SRC=$(toml_get "$main_config_t" cli-source) || DEF_CLI_SRC="j-hc/revanced-cli"
DEF_RV_BRAND=$(toml_get "$main_config_t" rv-brand) || DEF_RV_BRAND="ReVanced"
DEF_DPI_LIST=$(toml_get "$main_config_t" dpi) || DEF_DPI_LIST="nodpi anydpi"
mkdir -p "$TEMP_DIR" "$BUILD_DIR"

if [ "${2-}" = "--config-update" ]; then
	config_update
	exit 0
fi

# Resume mode
if [ "${2-}" = "--resume" ]; then
    pr "Resume mode enabled - skipping completed builds"
else
    clear_build_state
fi

: >build.md
ENABLE_MAGISK_UPDATE=$(toml_get "$main_config_t" enable-magisk-update) || ENABLE_MAGISK_UPDATE=true
if [ "$ENABLE_MAGISK_UPDATE" = true ] && [ -z "${GITHUB_REPOSITORY-}" ]; then
	pr "You are building locally. Magisk updates will not be enabled."
	ENABLE_MAGISK_UPDATE=false
fi
if ((COMPRESSION_LEVEL > 9)) || ((COMPRESSION_LEVEL < 0)); then abort "compression-level must be within 0-9"; fi

rm -rf revanced-magisk/bin/*/tmp.*
for file in "$TEMP_DIR"/*/changelog.md; do
    [ -f "$file" ] && : > "$file"
done

mkdir -p ${MODULE_TEMPLATE_DIR}/bin/arm64 ${MODULE_TEMPLATE_DIR}/bin/arm ${MODULE_TEMPLATE_DIR}/bin/x86 ${MODULE_TEMPLATE_DIR}/bin/x64
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-arm64-v8a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-armeabi-v7a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x86/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86_64"

# ============================================
# Build tracking function
# ============================================
build_app_wrapper() {
    local table_name="$1"
    local app_args_str="$2"
    local start_time
    start_time=$(date +%s)
    
    # Check if already completed (resume support)
    if load_build_state "$table_name"; then
        pr "Skipping $table_name (already completed)"
        return 0
    fi
    
    pr "Starting build: $table_name"
    
    if build_rv "$app_args_str"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        pr "Completed $table_name in ${duration}s"
        save_build_state "$table_name" "completed"
        SUCCESSFUL_BUILDS+=("$table_name")
        return 0
    else
        epr "Failed to build $table_name"
        save_build_state "$table_name" "failed"
        FAILED_BUILDS+=("$table_name")
        if [ "$CONTINUE_ON_ERROR" = "true" ]; then
            warn "Continuing with other builds..."
            return 0
        else
            return 1
        fi
    fi
}

declare -A cliriplib
idx=0
total_apps=0
built_apps=0

# Count total enabled apps
for table_name in $(toml_get_table_names); do
    if [ -z "$table_name" ]; then continue; fi
    t=$(toml_get_table "$table_name")
    enabled=$(toml_get "$t" enabled) || enabled=true
    if [ "$enabled" = true ]; then
        ((total_apps++)) || true
    fi
done

pr "Building $total_apps apps with $PARALLEL_JOBS parallel jobs"
pr "Target architecture: $DEFAULT_ARCH"
[ "$BUILD_LITE" = "true" ] && pr "Lite builds enabled"
for table_name in $(toml_get_table_names); do
	if [ -z "$table_name" ]; then continue; fi
	t=$(toml_get_table "$table_name")
	enabled=$(toml_get "$t" enabled) || enabled=true
	vtf "$enabled" "enabled"
	if [ "$enabled" = false ]; then continue; fi
	if ((idx >= PARALLEL_JOBS)); then
		wait -n
		idx=$((idx - 1))
	fi

	declare -A app_args
	patches_src=$(toml_get "$t" patches-source) || patches_src=$DEF_PATCHES_SRC
	patches_ver=$(toml_get "$t" patches-version) || patches_ver=$DEF_PATCHES_VER
	cli_src=$(toml_get "$t" cli-source) || cli_src=$DEF_CLI_SRC
	cli_ver=$(toml_get "$t" cli-version) || cli_ver=$DEF_CLI_VER

	if ! PREBUILTS="$(get_prebuilts "$cli_src" "$cli_ver" "$patches_src" "$patches_ver")"; then
		if [ "$CONTINUE_ON_ERROR" = "true" ]; then
			epr "Could not download prebuilts for $table_name, skipping..."
			continue
		else
			abort "could not download rv prebuilts"
		fi
	fi
	read -r cli_jar patches_jar <<<"$PREBUILTS"
	app_args[cli]=$cli_jar
	app_args[ptjar]=$patches_jar
	if [[ -v cliriplib[${app_args[cli]}] ]]; then app_args[riplib]=${cliriplib[${app_args[cli]}]}; else
		if [[ $(java -jar "${app_args[cli]}" patch 2>&1) == *rip-lib* ]]; then
			cliriplib[${app_args[cli]}]=true
			app_args[riplib]=true
		else
			cliriplib[${app_args[cli]}]=false
			app_args[riplib]=false
		fi
	fi
	if [ "${app_args[riplib]}" = "true" ] && [ "$(toml_get "$t" riplib)" = "false" ]; then app_args[riplib]=false; fi
	app_args[rv_brand]=$(toml_get "$t" rv-brand) || app_args[rv_brand]=$DEF_RV_BRAND

	app_args[excluded_patches]=$(toml_get "$t" excluded-patches) || app_args[excluded_patches]=""
	if [ -n "${app_args[excluded_patches]}" ] && [[ ${app_args[excluded_patches]} != *'"'* ]]; then abort "patch names inside excluded-patches must be quoted"; fi
	app_args[included_patches]=$(toml_get "$t" included-patches) || app_args[included_patches]=""
	if [ -n "${app_args[included_patches]}" ] && [[ ${app_args[included_patches]} != *'"'* ]]; then abort "patch names inside included-patches must be quoted"; fi
	app_args[exclusive_patches]=$(toml_get "$t" exclusive-patches) && vtf "${app_args[exclusive_patches]}" "exclusive-patches" || app_args[exclusive_patches]=false
	app_args[version]=$(toml_get "$t" version) || app_args[version]="auto"
	app_args[app_name]=$(toml_get "$t" app-name) || app_args[app_name]=$table_name
	app_args[patcher_args]=$(toml_get "$t" patcher-args) || app_args[patcher_args]=""
	app_args[table]=$table_name
	app_args[build_mode]=$(toml_get "$t" build-mode) && {
		if ! isoneof "${app_args[build_mode]}" both apk module; then
			abort "ERROR: build-mode '${app_args[build_mode]}' is not a valid option for '${table_name}': only 'both', 'apk' or 'module' is allowed"
		fi
	} || app_args[build_mode]=apk
	app_args[uptodown_dlurl]=$(toml_get "$t" uptodown-dlurl) && {
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%/}
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%download}
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%/}
		app_args[dl_from]=uptodown
	} || app_args[uptodown_dlurl]=""
	app_args[apkmirror_dlurl]=$(toml_get "$t" apkmirror-dlurl) && {
		app_args[apkmirror_dlurl]=${app_args[apkmirror_dlurl]%/}
		app_args[dl_from]=apkmirror
	} || app_args[apkmirror_dlurl]=""
	app_args[archive_dlurl]=$(toml_get "$t" archive-dlurl) && {
		app_args[archive_dlurl]=${app_args[archive_dlurl]%/}
		app_args[dl_from]=archive
	} || app_args[archive_dlurl]=""
	if [ -z "${app_args[dl_from]-}" ]; then abort "ERROR: no 'apkmirror_dlurl', 'uptodown_dlurl' or 'archive_dlurl' option was set for '$table_name'."; fi
	
	# Per-app architecture override or use default/global
	app_args[arch]=$(toml_get "$t" arch) || app_args[arch]="$DEFAULT_ARCH"
	if [ "${app_args[arch]}" != "both" ] && [ "${app_args[arch]}" != "all" ] && [[ ${app_args[arch]} != "arm64-v8a"* ]] && [[ ${app_args[arch]} != "arm-v7a"* ]] && [ "${app_args[arch]}" != "universal" ]; then
		abort "wrong arch '${app_args[arch]}' for '$table_name'"
	fi

	app_args[include_stock]=$(toml_get "$t" include-stock) || app_args[include_stock]=true && vtf "${app_args[include_stock]}" "include-stock"
	app_args[dpi]=$(toml_get "$t" dpi) || app_args[dpi]="$DEF_DPI_LIST"
	table_name_f=${table_name,,}
	table_name_f=${table_name_f// /-}
	app_args[module_prop_name]=$(toml_get "$t" module-prop-name) || app_args[module_prop_name]="${table_name_f}-jhc"

	# Per-app lite build setting
	app_args[build_lite]=$(toml_get "$t" build-lite) || app_args[build_lite]="$BUILD_LITE"

	if [ "${app_args[arch]}" = both ]; then
		app_args[table]="$table_name (arm64-v8a)"
		app_args[arch]="arm64-v8a"
		module_prop_name_b=${app_args[module_prop_name]}
		app_args[module_prop_name]="${module_prop_name_b}-arm64"
		idx=$((idx + 1))
		((built_apps++)) || true
		build_rv "$(declare -p app_args)" &
		app_args[table]="$table_name (arm-v7a)"
		app_args[arch]="arm-v7a"
		app_args[module_prop_name]="${module_prop_name_b}-arm"
		if ((idx >= PARALLEL_JOBS)); then
			wait -n
			idx=$((idx - 1))
		fi
		idx=$((idx + 1))
		((built_apps++)) || true
		build_rv "$(declare -p app_args)" &
	elif [ "${app_args[arch]}" = all ]; then
		# Build all architectures: arm64, arm, x86_64
		for build_arch in "arm64-v8a" "arm-v7a" "x86_64"; do
			app_args[table]="$table_name ($build_arch)"
			app_args[arch]="$build_arch"
			module_prop_name_b=${app_args[module_prop_name]}
			if [ "$build_arch" = "arm64-v8a" ]; then
				app_args[module_prop_name]="${module_prop_name_b}-arm64"
			elif [ "$build_arch" = "arm-v7a" ]; then
				app_args[module_prop_name]="${module_prop_name_b}-arm"
			else
				app_args[module_prop_name]="${module_prop_name_b}-${build_arch}"
			fi
			if ((idx >= PARALLEL_JOBS)); then
				wait -n
				idx=$((idx - 1))
			fi
			idx=$((idx + 1))
			((built_apps++)) || true
			build_rv "$(declare -p app_args)" &
		done
	else
		if [ "${app_args[arch]}" = "arm64-v8a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm64"
		elif [ "${app_args[arch]}" = "arm-v7a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm"
		fi
		idx=$((idx + 1))
		((built_apps++)) || true
		build_rv "$(declare -p app_args)" &
	fi
done
wait
rm -rf temp/tmp.*