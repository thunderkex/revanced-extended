#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

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

if [ "${1-}" = "clean" ]; then
	rm -rf temp build logs build.md "$BUILD_STATE_FILE"
	exit 0
fi

source utils.sh

trap "abort" INT

if [ "${1-}" = "clean" ]; then
	rm -r "$TEMP_DIR" "$BUILD_DIR" build.md
	exit 0
fi

jq --version >/dev/null || abort "\`jq\` is not installed. install it with 'apt install jq' or equivalent"
java --version >/dev/null || abort "\`openjdk 17\` is not installed. install it with 'apt install openjdk-17-jre' or equivalent"
zip --version >/dev/null || abort "\`zip\` is not installed. install it with 'apt install zip' or equivalent"

set_prebuilts

vtf() { if ! isoneof "${1}" "true" "false"; then abort "ERROR: '${1}' is not a valid option for '${2}': only true or false is allowed"; fi; }

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

# -- Main config --
toml_prep "${1:-config.toml}" || abort "could not find config file '${1:-config.toml}'\n\tUsage: $0 <config.toml>"
main_config_t=$(toml_get_table_main)
COMPRESSION_LEVEL=$(toml_get "$main_config_t" compression-level) || COMPRESSION_LEVEL="9"
if ! PARALLEL_JOBS=$(toml_get "$main_config_t" parallel-jobs); then
	if [ "$OS" = Android ]; then PARALLEL_JOBS=1; else PARALLEL_JOBS=$(nproc); fi
fi


CONTINUE_ON_ERROR=$(toml_get "$main_config_t" continue-on-error) || CONTINUE_ON_ERROR="true"
DOWNLOAD_TIMEOUT=$(toml_get "$main_config_t" download-timeout) || DOWNLOAD_TIMEOUT="30"
DOWNLOAD_RETRIES=$(toml_get "$main_config_t" download-retries) || DOWNLOAD_RETRIES="3"
DEFAULT_ARCH=$(toml_get "$main_config_t" default-arch) || DEFAULT_ARCH="arm64-v8a"
BUILD_LITE=$(toml_get "$main_config_t" build-lite) || BUILD_LITE="false"
LITE_BUILD_MODULES=$(toml_get "$main_config_t" lite-build-modules) || LITE_BUILD_MODULES="true"
LITE_LANGUAGES=$(toml_get "$main_config_t" lite-languages) || LITE_LANGUAGES="en"
LITE_DPI=$(toml_get "$main_config_t" lite-dpi) || LITE_DPI="xxhdpi"
LITE_COMPRESSION=$(toml_get "$main_config_t" lite-compression) || LITE_COMPRESSION="9"

DEFAULT_ARCH="${TARGET_ARCH:-$DEFAULT_ARCH}"
BUILD_LITE="${BUILD_LITE_ENV:-$BUILD_LITE}"

REMOVE_RV_INTEGRATIONS_CHECKS=$(toml_get "$main_config_t" remove-rv-integrations-checks) || REMOVE_RV_INTEGRATIONS_CHECKS="true"
DEF_PATCHES_VER=$(toml_get "$main_config_t" patches-version) || DEF_PATCHES_VER="latest"
DEF_CLI_VER=$(toml_get "$main_config_t" cli-version) || DEF_CLI_VER="latest"
DEF_PATCHES_SRC=$(toml_get "$main_config_t" patches-source) || DEF_PATCHES_SRC="ReVanced/revanced-patches"
DEF_CLI_SRC=$(toml_get "$main_config_t" cli-source) || DEF_CLI_SRC="ReVanced/revanced-cli"
DEF_RV_BRAND=$(toml_get "$main_config_t" rv-brand) || DEF_RV_BRAND="ReVanced"
mkdir -p "$TEMP_DIR" "$BUILD_DIR"

if [ "${2-}" = "--config-update" ]; then
	config_update
	exit 0
fi

if [ "${2-}" = "--resume" ]; then
    pr "Resume mode enabled - skipping completed builds"
else
    clear_build_state
fi

: >build.md
ENABLE_MODULE_UPDATE=$(toml_get "$main_config_t" enable-module-update) || ENABLE_MODULE_UPDATE=true
if [ "$ENABLE_MODULE_UPDATE" = true ] && [ -z "${GITHUB_REPOSITORY-}" ]; then
	pr "You are building locally. Module updates will not be enabled."
	ENABLE_MODULE_UPDATE=false
fi
if ((COMPRESSION_LEVEL > 9)) || ((COMPRESSION_LEVEL < 0)); then abort "compression-level must be within 0-9"; fi

rm -rf module/bin/*/tmp.*
for file in "$TEMP_DIR"/*/changelog.md; do
	[ -f "$file" ] && : >"$file"
done

mkdir -p ${MODULE_TEMPLATE_DIR}/bin/arm64 ${MODULE_TEMPLATE_DIR}/bin/arm ${MODULE_TEMPLATE_DIR}/bin/x86 ${MODULE_TEMPLATE_DIR}/bin/x64
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-arm64-v8a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-armeabi-v7a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x86/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86_64"

idx=0
total_apps=0
built_apps=0

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

	for dl_from in "${DL_SRCS[@]}"; do
		if app_args[${dl_from}_dlurl]=$(toml_get "$t" "${dl_from}-dlurl"); then
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%/}
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%download}
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%/}
			app_args[dl_from]=${dl_from}
		else
			app_args[${dl_from}_dlurl]=""
		fi
	done
	if [ -z "${app_args[dl_from]-}" ]; then abort "ERROR: no 'dlurl' option was set for '$table_name'. (${DL_SRCS[*]})"; fi
	app_args[arch]=$(toml_get "$t" arch) || app_args[arch]="$DEFAULT_ARCH"
	if ! isoneof "${app_args[arch]}" "both" "all" "arm64-v8a" "arm-v7a" "x86_64" "x86"; then
		abort "wrong arch '${app_args[arch]}' for '$table_name'"
	fi

	app_args[include_stock]=$(toml_get "$t" include-stock) || app_args[include_stock]=true && vtf "${app_args[include_stock]}" "include-stock"
	app_args[dpi]=$(toml_get "$t" dpi) || app_args[dpi]=""
	table_name_f=${table_name,,}
	table_name_f=${table_name_f// /-}
	app_args[module_prop_name]=$(toml_get "$t" module-prop-name) || app_args[module_prop_name]="${table_name_f}"

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

COMBINE_MODULES=$(toml_get "$main_config_t" combine-modules) || COMBINE_MODULES="false"
if [ "$COMBINE_MODULES" = true ]; then
	PACK_NAME=$(toml_get "$main_config_t" pack-name) || PACK_NAME="revpack"
	PACK_APPS=$(toml_get "$main_config_t" pack-apps) || PACK_APPS=""
	PACK_EXCLUDE=$(toml_get "$main_config_t" pack-exclude-apps) || PACK_EXCLUDE=""
	pr "Building RevPack: ${PACK_NAME}.zip"
	PACK_APPS="$PACK_APPS" PACK_EXCLUDE="$PACK_EXCLUDE" \
		ENABLE_MODULE_UPDATE="$ENABLE_MODULE_UPDATE" \
		GITHUB_REPOSITORY="${GITHUB_REPOSITORY-}" \
		bash "${CWD}/scripts/utilities/combine-modules.sh" "$PACK_NAME"
fi