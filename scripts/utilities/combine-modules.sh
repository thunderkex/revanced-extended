set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TEMP_DIR="$ROOT_DIR/temp"
PACK_TEMPLATE="$ROOT_DIR/module-combined"
MODULE_TEMPLATE="$ROOT_DIR/module"

PACK_NAME="${1:-revpack}"
VER_CODE=$(date +'%Y%m%d')
OUTPUT="$BUILD_DIR/${PACK_NAME}-v${VER_CODE}.zip"

PACK_APPS="${PACK_APPS:-}"
PACK_EXCLUDE="${PACK_EXCLUDE:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pr()    { echo -e "${GREEN}[+] ${1}${NC}"; }
info()  { echo -e "${CYAN}[*] ${1}${NC}"; }
warn()  { echo -e "${YELLOW}[!] ${1}${NC}"; }
epr()   { echo -e "${RED}[-] ${1}${NC}" >&2; }
abort() { epr "ABORT: ${1-}"; exit 1; }

normalise() {
    local s="${1// /-}"
    echo "${s,,}"
}

parse_list() {
    local raw="$1"
    local -n _out=$2
    IFS=',' read -ra _parts <<< "$raw"
    for part in "${_parts[@]}"; do
        part="${part#"${part%%[![:space:]\"\']*}"}"
        part="${part%"${part##*[![:space:]\"\']*}"}"
        part=$(normalise "$part")
        [ -n "$part" ] && _out+=("$part")
    done
}

should_include() {
    local zip_base="$1"
    local prefix="${zip_base%%-module-*}"

    if [ ${#INCLUDE_LIST[@]} -gt 0 ]; then
        local hit=false
        for item in "${INCLUDE_LIST[@]}"; do
            if [[ "$prefix" == "${item}" ]] || [[ "$prefix" == "${item}-"* ]]; then
                hit=true; break
            fi
        done
        [ "$hit" = true ] || return 1
    fi

    for item in "${EXCLUDE_LIST[@]}"; do
        if [[ "$prefix" == "${item}" ]] || [[ "$prefix" == "${item}-"* ]]; then
            return 1
        fi
    done

    return 0
}

INCLUDE_LIST=()
EXCLUDE_LIST=()
[ -n "$PACK_APPS" ]    && parse_list "$PACK_APPS"    INCLUDE_LIST
[ -n "$PACK_EXCLUDE" ] && parse_list "$PACK_EXCLUDE" EXCLUDE_LIST

if [ ${#INCLUDE_LIST[@]} -gt 0 ]; then
    info "Whitelist: ${INCLUDE_LIST[*]}"
fi
if [ ${#EXCLUDE_LIST[@]} -gt 0 ]; then
    info "Blacklist: ${EXCLUDE_LIST[*]}"
fi

[ -d "$BUILD_DIR" ]     || abort "build/ directory not found — run build.sh first."
[ -d "$PACK_TEMPLATE" ] || abort "module-combined/ template not found."

shopt -s nullglob
all_zips=("$BUILD_DIR"/*-module-*.zip)
shopt -u nullglob

filtered_zips=()
for z in "${all_zips[@]}"; do
    [[ "$(basename "$z")" == "${PACK_NAME}.zip" ]] && continue
    filtered_zips+=("$z")
done

if [ ${#filtered_zips[@]} -eq 0 ]; then
    abort "No '*-module-*.zip' files found in $BUILD_DIR — run build.sh first."
fi

pr "RevPack builder — ${#filtered_zips[@]} candidate module(s) found"

work_dir=$(mktemp -d -p "$TEMP_DIR" "revpack-tmp.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

cp -a "$PACK_TEMPLATE/." "$work_dir/"
mkdir -p "$work_dir/apps"

if [ -d "$MODULE_TEMPLATE/bin" ]; then
    cp -a "$MODULE_TEMPLATE/bin/." "$work_dir/bin/"
    pr "bin/ copied from module template"
else
    warn "module/bin/ not found — run build.sh first to download cmpr + ksu_profile binaries."
fi

apps_added=0
apps_skipped=0
declare -A seen_pkgs
MANIFEST_PKGS=()
MANIFEST_VERS=()
MANIFEST_ARCHS=()

for zip_file in "${filtered_zips[@]}"; do
    zip_base=$(basename "$zip_file")

    if ! should_include "$zip_base"; then
        info "  Skipping (filtered): $zip_base"
        apps_skipped=$((apps_skipped + 1))
        continue
    fi

    pr "Packing: $zip_base"

    ext_dir=$(mktemp -d -p "$TEMP_DIR" "rvpk-ext.XXXXXX")
    if ! unzip -q "$zip_file" -d "$ext_dir" 2>/dev/null; then
        warn "  Failed to extract $zip_base — skipping"
        rm -rf "$ext_dir"; continue
    fi

    if [ ! -f "$ext_dir/config" ]; then
        warn "  No 'config' file in $zip_base — skipping"
        rm -rf "$ext_dir"; continue
    fi

    unset PKG_NAME PKG_VER MODULE_ARCH
    . "$ext_dir/config"

    if [ -z "${PKG_NAME:-}" ]; then
        warn "  Empty PKG_NAME in $zip_base — skipping"
        rm -rf "$ext_dir"; continue
    fi

    if [ -n "${seen_pkgs[$PKG_NAME]+x}" ]; then
        warn "  Duplicate pkg '$PKG_NAME' from $zip_base — keeping first, skipping"
        rm -rf "$ext_dir"; continue
    fi
    seen_pkgs[$PKG_NAME]=1

    app_dir="$work_dir/apps/$PKG_NAME"
    mkdir -p "$app_dir"
    cp "$ext_dir/config" "$app_dir/config"

    if [ -f "$ext_dir/base.apk" ]; then
        cp "$ext_dir/base.apk" "$app_dir/base.apk"
        pr "  base.apk      → apps/$PKG_NAME/"
    else
        warn "  No base.apk in $zip_base"
    fi

    if [ -f "$ext_dir/${PKG_NAME}.apk" ]; then
        cp "$ext_dir/${PKG_NAME}.apk" "$app_dir/${PKG_NAME}.apk"
        pr "  ${PKG_NAME}.apk → apps/$PKG_NAME/"
    fi

    rm -rf "$ext_dir"
    apps_added=$((apps_added + 1))
    MANIFEST_PKGS+=("$PKG_NAME")
    MANIFEST_VERS+=("${PKG_VER:-}")
    MANIFEST_ARCHS+=("${MODULE_ARCH:-}")
done

if [ "$apps_added" -eq 0 ]; then
    abort "No modules added. Check pack-apps / pack-exclude-apps in config.toml."
fi

[ "$apps_skipped" -gt 0 ] && info "$apps_skipped module(s) filtered out"

PKG_LIST=$(printf '%s\n' "${!seen_pkgs[@]}" | sed 's/^com\.\|^org\.\|^tv\.\|^net\.//' | paste -sd ', ' -)
ENABLE_MODULE_UPDATE="${ENABLE_MODULE_UPDATE:-false}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
if [ "$ENABLE_MODULE_UPDATE" = true ] && [ -z "$GITHUB_REPOSITORY" ]; then
    warn "Local build — RevPack updateJson will not be set (no GITHUB_REPOSITORY)"
    ENABLE_MODULE_UPDATE=false
fi
cat > "$work_dir/module.prop" <<EOF
id=${PACK_NAME}
name=RevPack (${apps_added} apps)
version=v${VER_CODE}
versionCode=${VER_CODE}
author=Thunderkex
description=RevPack — ${apps_added} patched app(s): ${PKG_LIST}
EOF
if [ "$ENABLE_MODULE_UPDATE" = true ]; then
    UPDATE_JSON_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/update/${PACK_NAME}-update.json"
    echo "updateJson=${UPDATE_JSON_URL}" >> "$work_dir/module.prop"
    pr "updateJson set: ${UPDATE_JSON_URL}"
fi

mkdir -p "$work_dir/webroot"
APPS_JSON='[]'
for i in "${!MANIFEST_PKGS[@]}"; do
    APPS_JSON=$(jq -n \
        --argjson arr "$APPS_JSON" \
        --arg pkg  "${MANIFEST_PKGS[$i]}" \
        --arg ver  "${MANIFEST_VERS[$i]}" \
        --arg arch "${MANIFEST_ARCHS[$i]}" \
        '$arr + [{pkg: $pkg, moduleVer: $ver, moduleArch: $arch}]')
done
jq -n \
    --arg id      "$PACK_NAME" \
    --arg version "v${VER_CODE}" \
    --arg vcode   "$VER_CODE" \
    --argjson apps "$APPS_JSON" \
    '{id: $id, version: $version, versionCode: $vcode, apps: $apps}' \
    > "$work_dir/webroot/manifest.json"
pr "WebUI manifest.json → ${apps_added} app(s) baked in"

pr "Zipping RevPack → $(basename "$OUTPUT")  (${apps_added} apps)"
pushd "$work_dir" >/dev/null
zip -9 -FSqr "$OUTPUT" .
popd >/dev/null

SIZE=$(du -sh "$OUTPUT" | cut -f1)
pr ""
pr "RevPack ready: $OUTPUT  [${SIZE}]"
pr "Flash via Magisk / KernelSU to install ${apps_added} app(s) at once."
