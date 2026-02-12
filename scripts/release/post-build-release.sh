#!/usr/bin/env bash
# ============================================
# Post-Build Release Script
# ============================================
# Called after successful build to update the
# single mutable release with new assets.
#
# This script is designed to be called from
# GitHub Actions workflow after build completes.
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

# Source the release manager
source "${SCRIPT_DIR}/release-manager.sh" 2>/dev/null || {
    echo "Error: release-manager.sh not found"
    exit 1
}

# Source the downloads generator
source "${SCRIPT_DIR}/generate-readme-downloads.sh" 2>/dev/null || {
    echo "Warning: generate-readme-downloads.sh not found, skipping README update"
}

# Configuration
RELEASE_TAG="${RELEASE_TAG:-latest-build}"
RELEASE_NAME="${RELEASE_NAME:-ReVanced Extended - Latest Build}"
BUILD_DIR="${BUILD_DIR:-build}"

# Generate release notes from build.md or changelog
generate_release_notes() {
    local notes_file="release_notes.md"
    local build_date
    build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    cat > "$notes_file" << EOF
# 🚀 ReVanced Extended - Latest Build

> **Auto-updated:** ${build_date}

EOF
    
    # Add build info if available
    if [[ -f "build.md" ]]; then
        echo "## 📦 Build Information" >> "$notes_file"
        echo "" >> "$notes_file"
        cat "build.md" >> "$notes_file"
        echo "" >> "$notes_file"
    fi
    
    # Add asset list
    echo "## 📥 Downloads" >> "$notes_file"
    echo "" >> "$notes_file"
    echo "All assets below are the **latest versions**. Simply download and install!" >> "$notes_file"
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
    
    # Add installation instructions
    cat >> "$notes_file" << 'EOF'
## 📲 Installation

### Magisk/KernelSU Module
1. Download the `.zip` module file
2. Install via Magisk/KernelSU app
3. Reboot device

### Non-Root APK
1. Download the `.apk` file
2. Install using your package installer
3. If updating, uninstall the previous version first

## ⚠️ Important Notes

- **Magisk users**: Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to prevent Play Store updates
- **Module updates**: Magisk will notify you of updates automatically
- **This release is automatically updated** - assets are always current

---

EOF
    
    echo "$notes_file"
}

# Main execution
main() {
    echo "=========================================="
    echo " Post-Build Release"
    echo "=========================================="
    
    # Check required environment
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        echo "Error: GITHUB_REPOSITORY not set"
        exit 1
    fi
    
    # Check for build artifacts
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
    
    # Generate release notes
    echo "Generating release notes..."
    local notes_file
    notes_file=$(generate_release_notes)
    
    # Generate README downloads section
    echo "Generating README downloads..."
    if type generate_downloads_section &>/dev/null; then
        # Export variables for the generator
        export BUILD_DIR
        export RELEASE_TAG
        export REPO_URL="https://github.com/${GITHUB_REPOSITORY}"
        export README_FILE="${PROJECT_ROOT}/README.md"
        export DOWNLOADS_MD="${PROJECT_ROOT}/DOWNLOADS.md"
        
        # Update README and DOWNLOADS.md
        update_readme "$REPO_URL" 2>/dev/null || echo "Warning: Failed to update README"
        generate_downloads_md "$REPO_URL" > "$DOWNLOADS_MD" 2>/dev/null || echo "Warning: Failed to generate DOWNLOADS.md"
        
        # Commit and push documentation updates
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "Committing documentation updates..."
            git config --local user.email "action@github.com"
            git config --local user.name "GitHub Action"
            git add README.md DOWNLOADS.md 2>/dev/null || true
            git diff --staged --quiet || git commit -m "📝 Update downloads [skip ci]" 2>/dev/null || true
            git push 2>/dev/null || echo "Warning: Failed to push documentation updates"
        fi
    fi
    
    # Run full release cycle
    echo "Updating release '$RELEASE_TAG'..."
    
    # Export for release-manager.sh
    export GITHUB_TOKEN
    export GITHUB_REPOSITORY
    export RELEASE_TAG
    export RELEASE_NAME
    export BUILD_DIR
    export GH_TOKEN="$GITHUB_TOKEN"
    
    # Initialize release if needed
    init_release
    
    # # Clean old assets
    # clean_assets
    
    # Upload new assets
    upload_assets
    
    # Update release body
    update_body "$notes_file"
    
    echo ""
    echo "=========================================="
    echo " Release Updated Successfully!"
    echo "=========================================="
    echo ""
    echo "Release URL: https://github.com/${GITHUB_REPOSITORY}/releases/tag/${RELEASE_TAG}"
    echo ""
    
    # List final assets
    list_assets
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
