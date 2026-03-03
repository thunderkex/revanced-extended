#!/usr/bin/env bash
# ============================================
# Asset Utilities for Release Management
# ============================================
# Helper functions for managing release assets
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1" >&2; }

# Check rate limits
check_rate_limit() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        error "GITHUB_TOKEN required"
        return 1
    fi
    
    local limits
    limits=$(gh api rate_limit --jq '.resources.core | "Remaining: \(.remaining)/\(.limit), Resets: \(.reset | strftime("%Y-%m-%d %H:%M:%S UTC"))"')
    
    echo "GitHub API Rate Limits:"
    echo "  $limits"
}

# Get download statistics
get_download_stats() {
    local tag="${1:-latest-build}"
    local repo="${GITHUB_REPOSITORY:-}"
    
    if [[ -z "$repo" ]]; then
        repo=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]||;s|\.git$||')
    fi
    
    if [[ -z "$repo" ]]; then
        error "Could not determine repository"
        return 1
    fi
    
    echo "Download Statistics for release: $tag"
    echo "============================================"
    
    gh api "repos/${repo}/releases/tags/${tag}" \
        --jq '.assets[] | "\(.name): \(.download_count) downloads (\(.size / 1048576 | floor)MB)"' 2>/dev/null || echo "No assets found"
    
    echo ""
    local total
    total=$(gh api "repos/${repo}/releases/tags/${tag}" \
        --jq '[.assets[].download_count] | add // 0' 2>/dev/null || echo "0")
    echo "Total downloads: $total"
}

# Recreate release if accidentally deleted
recreate_release() {
    local tag="${1:-latest-build}"
    local name="${2:-ReVanced Extended - Latest Build}"
    local repo="${GITHUB_REPOSITORY:-}"
    
    if [[ -z "$repo" ]]; then
        error "GITHUB_REPOSITORY required"
        return 1
    fi
    
    log "Recreating release: $tag"
    
    # Check if already exists
    if gh release view "$tag" --repo "$repo" &>/dev/null; then
        warn "Release already exists"
        return 0
    fi
    
    # Create fresh release
    gh release create "$tag" \
        --repo "$repo" \
        --title "$name" \
        --notes "🚀 Release recreated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')

This release will be updated with assets on the next build." \
        --latest
    
    log "Release recreated successfully"
}

# Verify asset integrity (check all expected files exist)
verify_assets() {
    local tag="${1:-latest-build}"
    local expected_patterns=("*.apk" "*.zip")
    local build_dir="${BUILD_DIR:-build}"
    
    log "Verifying release assets match build output..."
    
    # Get release assets
    local release_assets
    release_assets=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${tag}" \
        --jq '.assets[].name' 2>/dev/null | sort)
    
    # Get build files
    local build_files=""
    for pattern in "${expected_patterns[@]}"; do
        for f in "$build_dir"/$pattern; do
            [[ -f "$f" ]] && build_files+="$(basename "$f")"$'\n'
        done
    done
    build_files=$(echo "$build_files" | sort | grep -v '^$')
    
    # Compare
    local missing=()
    local extra=()
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if ! echo "$release_assets" | grep -qF "$file"; then
            missing+=("$file")
        fi
    done <<< "$build_files"
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing from release:"
        printf '  - %s\n' "${missing[@]}"
        return 1
    fi
    
    log "All build files are in release"
    return 0
}

# Generate direct download URLs
get_download_urls() {
    local tag="${1:-latest-build}"
    local repo="${GITHUB_REPOSITORY:-}"
    
    if [[ -z "$repo" ]]; then
        repo=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]||;s|\.git$||')
    fi
    
    echo "Direct Download URLs:"
    echo "====================="
    
    gh api "repos/${repo}/releases/tags/${tag}" \
        --jq '.assets[] | "https://github.com/'"$repo"'/releases/download/'"$tag"'/\(.name)"' 2>/dev/null || echo "No assets"
}

# Show help
show_help() {
    cat << EOF
Asset Utilities

Usage: $(basename "$0") <command> [options]

Commands:
  rate-limit        Check GitHub API rate limits
  stats [tag]       Show download statistics
  recreate [tag]    Recreate deleted release
  verify [tag]      Verify assets match build
  urls [tag]        Get direct download URLs

Environment:
  GITHUB_TOKEN      Required for API calls
  GITHUB_REPOSITORY Repository in owner/repo format
EOF
}

# Main
main() {
    local command="${1:-help}"
    shift || true
    
    export GH_TOKEN="${GITHUB_TOKEN:-}"
    
    case "$command" in
        rate-limit|rate_limit|ratelimit)
            check_rate_limit
            ;;
        stats|downloads)
            get_download_stats "$@"
            ;;
        recreate)
            recreate_release "$@"
            ;;
        verify)
            verify_assets "$@"
            ;;
        urls|download-urls)
            get_download_urls "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
