set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1" >&2; }
debug() { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${BLUE}[D]${NC} $1"; }

RELEASE_TAG="${RELEASE_TAG:-latest-build}"
RELEASE_NAME="${RELEASE_NAME:-ReVanced Extended - Latest Build}"
BUILD_DIR="${BUILD_DIR:-build}"
PARALLEL_UPLOADS="${PARALLEL_UPLOADS:-4}"
RETRY_COUNT="${RETRY_COUNT:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

check_env() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        error "GITHUB_TOKEN is required"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        # Try to detect from git remote
        GITHUB_REPOSITORY=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]||;s|\.git$||' || echo "")
        if [[ -z "$GITHUB_REPOSITORY" ]]; then
            error "GITHUB_REPOSITORY is required (format: owner/repo)"
            exit 1
        fi
    fi
    
    export GH_TOKEN="$GITHUB_TOKEN"
    debug "Repository: $GITHUB_REPOSITORY"
    debug "Release tag: $RELEASE_TAG"
}

get_release_id() {
    local response
    response=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" 2>/dev/null) || return 1
    echo "$response" | jq -r '.id // empty' 2>/dev/null || echo ""
}

release_exists() {
    gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" &>/dev/null
}

init_release() {
    log "Initializing release..."
    
    if release_exists; then
        log "Release '$RELEASE_TAG' already exists"
        return 0
    fi
    
    log "Creating release '$RELEASE_TAG'..."
    
    gh release create "$RELEASE_TAG" \
        --repo "$GITHUB_REPOSITORY" \
        --title "$RELEASE_NAME" \
        --notes "🚀 **ReVanced Extended - Latest Build**

This release is automatically updated with each new build.

**Assets below are always the latest versions.**

---
*Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')*" \
        --latest \
        2>/dev/null || {
            gh release create "$RELEASE_TAG" \
                --repo "$GITHUB_REPOSITORY" \
                --title "$RELEASE_NAME" \
                --notes "Initializing..." \
                --target "$(git rev-parse HEAD 2>/dev/null || echo 'main')" \
                --latest
        }
    
    log "Release created successfully"
}

clean_assets() {
    log "Cleaning existing assets..."
    
    if ! release_exists; then
        warn "Release doesn't exist, nothing to clean"
        return 0
    fi
    
    local api_response asset_ids
    
    set +o pipefail
    
    api_response=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" 2>/dev/null || echo "{}")
    asset_ids=$(echo "$api_response" | jq -r '.assets[]?.id // empty' 2>/dev/null || echo "")
    
    set -o pipefail
    
    if [[ -z "$asset_ids" || "$asset_ids" == "null" ]]; then
        log "No assets to clean"
        return 0
    fi
    
    local count=0
    local failed=0
    while IFS= read -r asset_id; do
        [[ -z "$asset_id" || "$asset_id" == "null" ]] && continue
        debug "Deleting asset ID: $asset_id"
        
        local deleted=false
        for attempt in 1 2 3; do
            if gh api -X DELETE "repos/${GITHUB_REPOSITORY}/releases/assets/${asset_id}" &>/dev/null; then
                deleted=true
                break
            fi
            sleep 1
        done
        
        if [[ "$deleted" == "true" ]]; then
            count=$((count + 1))
        else
            failed=$((failed + 1))
            warn "Failed to delete asset ID: $asset_id"
        fi
    done <<< "$asset_ids"
    
    if [[ $failed -gt 0 ]]; then
        log "Deleted $count assets ($failed failed)"
    else
        log "Deleted $count assets"
    fi
    
    return 0
}

delete_asset_by_name() {
    local filename="$1"
    local api_response asset_id
    
    set +o pipefail
    api_response=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" 2>/dev/null || echo "{}")
    asset_id=$(echo "$api_response" | jq -r --arg name "$filename" '.assets[] | select(.name == $name) | .id // empty' 2>/dev/null || echo "")
    set -o pipefail
    
    if [[ -n "$asset_id" && "$asset_id" != "null" ]]; then
        debug "Deleting existing asset '$filename' (ID: $asset_id)..."
        for attempt in 1 2 3; do
            if gh api -X DELETE "repos/${GITHUB_REPOSITORY}/releases/assets/${asset_id}" &>/dev/null; then
                debug "Deleted existing asset: $filename"
                return 0
            fi
            sleep 1
        done
        warn "Could not delete existing asset '$filename', will attempt clobber upload"
    fi
    return 0
}

delete_assets_by_pattern() {
    local pattern="$1"
    local api_response
    
    set +o pipefail
    api_response=$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" 2>/dev/null || echo "{}")
    
    while IFS=$'\t' read -r asset_id asset_name; do
        [[ -z "$asset_id" || "$asset_id" == "null" ]] && continue
        case "$asset_name" in
            $pattern)
                debug "Deleting old asset '$asset_name' (ID: $asset_id)..."
                local deleted=false
                for attempt in 1 2 3; do
                    if gh api -X DELETE "repos/${GITHUB_REPOSITORY}/releases/assets/${asset_id}" &>/dev/null; then
                        log "Deleted old revpack asset: $asset_name"
                        deleted=true
                        break
                    fi
                    sleep 1
                done
                [[ "$deleted" == false ]] && warn "Could not delete old asset '$asset_name'"
                ;;
        esac
    done < <(echo "$api_response" | jq -r '.assets[] | [.id, .name] | @tsv' 2>/dev/null || true)
    
    set -o pipefail
}

upload_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    if [[ "$filename" == revpack-*.zip ]]; then
        if [[ "${PRESERVE_REVPACK:-false}" != "true" ]]; then
            delete_assets_by_pattern "revpack-*.zip"
        else
            debug "PRESERVE_REVPACK=true — keeping existing revpack assets alongside $filename"
        fi
    else
        delete_asset_by_name "$filename"
    fi
    
    for ((i=1; i<=RETRY_COUNT; i++)); do
        debug "Uploading $filename (attempt $i/$RETRY_COUNT)..."
        
        if gh release upload "$RELEASE_TAG" "$file" \
            --repo "$GITHUB_REPOSITORY" \
            --clobber 2>/dev/null; then
            log "✓ Uploaded: $filename"
            return 0
        fi
        
        if [[ $i -lt $RETRY_COUNT ]]; then
            warn "Upload failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
    done
    
    error "Failed to upload: $filename"
    return 1
}

upload_assets() {
    log "Uploading assets from '$BUILD_DIR'..."
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        error "Build directory not found: $BUILD_DIR"
        exit 1
    fi
    
    init_release
    
    local files=()
    for file in "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.zip; do
        [[ -f "$file" ]] && files+=("$file")
    done
    
    if [[ ${#files[@]} -eq 0 ]]; then
        warn "No APK or ZIP files found in $BUILD_DIR"
        return 0
    fi
    
    log "Found ${#files[@]} files to upload"
    
    local failed=0
    if [[ $PARALLEL_UPLOADS -gt 1 ]] && command -v parallel &>/dev/null; then
        export -f delete_asset_by_name upload_file log warn error debug
        export RELEASE_TAG GITHUB_REPOSITORY RETRY_COUNT RETRY_DELAY DEBUG
        printf '%s\n' "${files[@]}" | parallel -j "$PARALLEL_UPLOADS" upload_file {}
        failed=$((${PIPESTATUS[0]:-0}))
    else
        for file in "${files[@]}"; do
            upload_file "$file" || ((failed++))
        done
    fi
    
    if [[ $failed -gt 0 ]]; then
        error "$failed file(s) failed to upload"
        return 1
    fi
    
    log "All assets uploaded successfully"
}

update_body() {
    local body_file="${1:-}"
    local body=""
    
    log "Updating release body..."
    
    if [[ -n "$body_file" && -f "$body_file" ]]; then
        body=$(cat "$body_file")
    elif [[ -f "release_notes.md" ]]; then
        body=$(cat "release_notes.md")
    elif [[ -f "build.md" ]]; then
        body=$(cat "build.md")
    else
        body="🚀 **ReVanced Extended - Latest Build**

This release is automatically updated with each new build.

---
*Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')*"
    fi
    
    gh release edit "$RELEASE_TAG" \
        --repo "$GITHUB_REPOSITORY" \
        --title "$RELEASE_NAME" \
        --notes "$body" \
        --latest
    
    log "Release body updated"
}

move_tag() {
    log "Moving tag to current commit..."
    
    local current_commit
    current_commit=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    if [[ -z "$current_commit" ]]; then
        warn "Not in a git repository, skipping tag move"
        return 0
    fi
    
    git tag -d "$RELEASE_TAG" 2>/dev/null || true
    git push origin ":refs/tags/$RELEASE_TAG" 2>/dev/null || true
    git tag "$RELEASE_TAG" "$current_commit"
    git push origin "$RELEASE_TAG" --force 2>/dev/null || true
    
    log "Tag moved to $current_commit"
}

list_assets() {
    log "Listing release assets..."
    
    if ! release_exists; then
        error "Release '$RELEASE_TAG' does not exist"
        return 1
    fi
    
    echo ""
    echo "Release: $RELEASE_TAG"
    echo "========================"
    
    gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}" \
        --jq '.assets[] | "  \(.name) (\(.size / 1048576 | floor)MB) - \(.download_count) downloads"' 2>/dev/null || echo "  No assets"
    
    echo ""
}

full_cycle() {
    log "Starting full release cycle..."
    
    init_release
    clean_assets
    upload_assets
    update_body "${1:-}"
    
    log "Release cycle complete!"
    list_assets
}

delete_release() {
    warn "Deleting release '$RELEASE_TAG'..."
    
    if ! release_exists; then
        log "Release doesn't exist"
        return 0
    fi
    
    gh release delete "$RELEASE_TAG" \
        --repo "$GITHUB_REPOSITORY" \
        --yes \
        --cleanup-tag 2>/dev/null || true
    
    log "Release deleted"
}

show_help() {
    cat << EOF
Single Mutable Release Manager

Usage: $(basename "$0") <command> [options]

Commands:
  init          Create release if it doesn't exist
  clean         Delete all assets from release
  upload        Upload files from build directory
  update-body   Update release description
  move-tag      Move tag to current commit
  list          List current assets
  full-cycle    Run complete release cycle (clean -> upload -> update)
  delete        Delete the release entirely

Environment Variables:
  GITHUB_TOKEN       Required: GitHub API token
  GITHUB_REPOSITORY  Required: owner/repo format
  RELEASE_TAG        Release tag name (default: latest-build)
  RELEASE_NAME       Release display name
  BUILD_DIR          Build output directory (default: build)
  PARALLEL_UPLOADS   Concurrent uploads (default: 4)
  DEBUG              Enable debug output (default: false)

Examples:
  # Full automated release
  GITHUB_TOKEN=xxx GITHUB_REPOSITORY=user/repo ./$(basename "$0") full-cycle

  # Upload with custom build directory
  BUILD_DIR=./output ./$(basename "$0") upload

  # List assets
  ./$(basename "$0") list
EOF
}

main() {
    local command="${1:-help}"
    shift || true
    
    check_env
    
    case "$command" in
        init)
            init_release
            ;;
        clean)
            clean_assets
            ;;
        upload)
            upload_assets
            ;;
        update-body)
            update_body "$@"
            ;;
        move-tag)
            move_tag
            ;;
        list)
            list_assets
            ;;
        full-cycle)
            full_cycle "$@"
            ;;
        delete)
            delete_release
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
