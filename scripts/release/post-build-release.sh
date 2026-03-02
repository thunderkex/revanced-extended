set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

source "${SCRIPT_DIR}/release-manager.sh" 2>/dev/null || {
    echo "Error: release-manager.sh not found"
    exit 1
}

source "${SCRIPT_DIR}/generate-readme-downloads.sh" 2>/dev/null || {
    echo "Warning: generate-readme-downloads.sh not found, skipping README update"
}

RELEASE_TAG="${RELEASE_TAG:-latest-build}"
RELEASE_NAME="${RELEASE_NAME:-ReVanced Extended - Latest Build}"
BUILD_DIR="${BUILD_DIR:-build}"

generate_release_notes() {
    local notes_file="release_notes.md"
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    cat > "$notes_file" << EOF
# 🚀 ReVanced Extended - Latest Build Download & Release Notes

> **Auto-updated:** ${build_date}

Welcome to the custom **ReVanced Extended** latest build release page. Here you can download the most recent APK and Magisk/KernelSU module files, view detailed build information, and find step-by-step installation instructions. Stay up-to-date with the best YouTube mod for Android!

EOF

    if [[ -f "build.md" ]]; then
        echo "## 📦 Build Information & Changelog" >> "$notes_file"
        echo "" >> "$notes_file"
        cat "build.md" >> "$notes_file"
        echo "" >> "$notes_file"
    fi

    echo "## 📥 Download Latest ReVanced Extended APK & Modules" >> "$notes_file"
    echo "" >> "$notes_file"
    echo "Below are the **latest versions** of all available assets. Download and install to enjoy the newest features and fixes!" >> "$notes_file"
    echo "" >> "$notes_file"

    if [[ -d "$BUILD_DIR" ]]; then
        echo "| File | Size |" >> "$notes_file"
        echo "|------|------|" >> "$notes_file"

        for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
            [[ -f "$file" ]] || continue
            local filename
            filename=$(basename "$file")
            local size
            size=$(du -h "$file" | cut -f1)
            echo "| \`$filename\` | $size |" >> "$notes_file"
        done
        echo "" >> "$notes_file"
    fi

    cat >> "$notes_file" << 'EOF'
## 📲 How to Install ReVanced Extended

### Magisk/KernelSU Module Installation
1. Download the `.zip` module file from the list above.
2. Open your Magisk or KernelSU app and install the module.
3. Reboot your Android device to activate the module.

### Non-Root APK Installation
1. Download the `.apk` file from the downloads section.
2. Use your preferred package installer to install the APK.
3. If updating, uninstall the previous version before installing the new one.

## ⚠️ Important Notes for Users

- **Magisk users:** Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent unwanted Play Store updates.
- **Automatic Updates:** Magisk will notify you when module updates are available.
- **Always Current:** This release page is automatically updated with the latest ReVanced Extended builds and assets.

---

For more information, troubleshooting, and support, visit the [ReVanced Extended GitHub repository](https://github.com/thunderkex/revanced-extended).

EOF

    echo "$notes_file"
}

main() {
    echo "=========================================="
    echo " Post-Build Release"
    echo "=========================================="
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        echo "Error: GITHUB_REPOSITORY not set"
        exit 1
    fi
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Error: Build directory not found: $BUILD_DIR"
        exit 1
    fi
    
    local file_count
    file_count=$(find "$BUILD_DIR" -maxdepth 1 \( -name "*.apk" -o -name "*.zip" \) | wc -l)
    
    if [[ $file_count -eq 0 ]]; then
        echo "Warning: No APK or ZIP files found in $BUILD_DIR"
        echo "Skipping release update"
        exit 0
    fi
    
    echo "Found $file_count build artifacts"
    
    echo "Generating release notes..."
    local notes_file
    notes_file=$(generate_release_notes)
    
    echo "Updating release '$RELEASE_TAG'..."

    export GITHUB_TOKEN
    export GITHUB_REPOSITORY
    export RELEASE_TAG
    export RELEASE_NAME
    export BUILD_DIR
    export GH_TOKEN="$GITHUB_TOKEN"

    init_release


    upload_assets

    update_body "$notes_file"

    echo "Generating README downloads..."
    if type generate_downloads_section &>/dev/null; then
        export BUILD_DIR
        export RELEASE_TAG
        export REPO_URL="https://github.com/${GITHUB_REPOSITORY}"
        export README_FILE="${PROJECT_ROOT}/README.md"
        export DOWNLOADS_MD="${PROJECT_ROOT}/DOWNLOADS.md"
        export USE_RELEASE_ASSETS=true

        update_readme "$REPO_URL" 2>/dev/null || echo "Warning: Failed to update README"
        generate_downloads_md "$REPO_URL" > "$DOWNLOADS_MD" 2>/dev/null || echo "Warning: Failed to generate DOWNLOADS.md"

        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "Committing documentation updates..."
            git config --local user.email "action@github.com"
            git config --local user.name "GitHub Action"
            git add README.md DOWNLOADS.md 2>/dev/null || true
            git diff --staged --quiet || git commit -m "📝 Update downloads [skip ci]" 2>/dev/null || true
            git push 2>/dev/null || echo "Warning: Failed to push documentation updates"
        fi
    fi
    
    echo ""
    echo "=========================================="
    echo " Release Updated Successfully!"
    echo "=========================================="
    echo ""
    echo "Release URL: https://github.com/${GITHUB_REPOSITORY}/releases/tag/${RELEASE_TAG}"
    echo ""
    
    list_assets
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
