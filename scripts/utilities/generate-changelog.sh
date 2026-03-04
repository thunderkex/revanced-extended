#!/usr/bin/env bash
# ============================================
# Changelog Generator
# Generates changelogs from patch sources and build outputs
# Inspired by semantic-release style changelogs
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-build}"
TEMP_DIR="${TEMP_DIR:-temp}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
epr() { echo -e "\033[0;31m[-] ${1}\033[0m" >&2; }

# Generate changelog header
generate_header() {
    local version="$1"
    local date
    date=$(date +"%Y-%m-%d")
    
    cat <<EOF
# Changelog

All notable changes to ReVanced Extended builds are documented here.

## [$version] - $date

EOF
}

# Extract patch release notes from GitHub
fetch_patch_changelog() {
    local repo="$1"
    local version="$2"
    local gh_token="${GITHUB_TOKEN:-}"
    
    local headers=""
    if [ -n "$gh_token" ]; then
        headers="-H 'Authorization: token $gh_token'"
    fi
    
    local api_url="https://api.github.com/repos/$repo/releases/tags/$version"
    local response
    
    if response=$(curl -sL $headers "$api_url" 2>/dev/null); then
        local body
        body=$(echo "$response" | jq -r '.body // empty')
        if [ -n "$body" ]; then
            echo "$body"
        fi
    fi
}

# Generate build artifacts section
generate_artifacts_section() {
    local output=""
    
    output+="### Build Artifacts\n\n"
    
    # Group by app
    declare -A apps
    for file in "$BUILD_DIR"/*; do
        [ -f "$file" ] || continue
        local filename
        filename=$(basename "$file")
        local app_name
        # Extract app name (first part before version)
        app_name=$(echo "$filename" | sed 's/-v[0-9].*//' | sed 's/-revanced.*//' | sed 's/-morphed.*//')
        apps["$app_name"]+="$filename\n"
    done
    
    for app in "${!apps[@]}"; do
        output+="#### ${app^}\n"
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            local size
            size=$(du -h "$BUILD_DIR/$file" 2>/dev/null | cut -f1)
            output+="- \`$file\` ($size)\n"
        done < <(echo -e "${apps[$app]}")
        output+="\n"
    done
    
    echo -e "$output"
}

# Generate patches section
generate_patches_section() {
    local output=""
    output+="### Patches Applied\n\n"
    
    # Read from build.md if available
    if [ -f "build.md" ]; then
        local patches_info
        patches_info=$(grep -E "^Patches:" build.md || true)
        if [ -n "$patches_info" ]; then
            while IFS= read -r line; do
                output+="- $line\n"
            done <<< "$patches_info"
        fi
    fi
    
    echo -e "$output"
}

# Generate full changelog
generate_changelog() {
    local version="${1:-$(date +%Y%m%d)}"
    local output_file="${2:-$CHANGELOG_FILE}"
    
    pr "Generating changelog for version $version..."
    
    {
        generate_header "$version"
        generate_patches_section
        generate_artifacts_section
        
        echo "### Links"
        echo ""
        echo "- [MicroG-RE](https://github.com/WSTxda/MicroG-RE/releases) - Required for non-root YouTube/YT Music"
        echo "- [zygisk-detach](https://github.com/j-hc/zygisk-detach) - Prevent Play Store updates"
        echo ""
        
        # Append previous changelog if exists
        if [ -f "$output_file" ]; then
            echo "---"
            echo ""
            # Skip header from old changelog
            tail -n +4 "$output_file" 2>/dev/null || true
        fi
    } > "${output_file}.new"
    
    mv "${output_file}.new" "$output_file"
    pr "Changelog generated: $output_file"
}

# Generate release notes (shorter format for GitHub releases)
generate_release_notes() {
    local version="${1:-$(date +%Y%m%d)}"
    
    cat <<EOF
## ReVanced Extended v$version

### Downloads
$(generate_artifacts_section | sed 's/^####/###/')

### Installation
- **Non-root:** Install APK directly, requires [MicroG-RE](https://github.com/WSTxda/MicroG-RE/releases)
- **Root (Magisk/KernelSU):** Flash the zip file in Magisk/KSU

### Notes
- Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent Play Store from updating patched apps
- Report issues at: https://github.com/thunderkex/revanced-extended/issues
EOF
}

# Main entry point
main() {
    case "${1:-generate}" in
        generate)
            generate_changelog "${2:-}" "${3:-}"
            ;;
        release-notes)
            generate_release_notes "${2:-}"
            ;;
        help|--help|-h)
            cat <<EOF
Usage: $0 [generate|release-notes] [version] [output-file]

Commands:
  generate       Generate full CHANGELOG.md
  release-notes  Generate GitHub release notes format

Environment:
  GITHUB_TOKEN   GitHub API token for fetching release notes
  BUILD_DIR      Directory with build artifacts (default: build)
  
Examples:
  ./generate-changelog.sh generate v24.01.15
  ./generate-changelog.sh release-notes 20240115
EOF
            ;;
        *)
            epr "Unknown command: $1"
            exit 1
            ;;
    esac
}

main "$@"
