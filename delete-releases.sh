#!/bin/bash

# Script to delete all GitHub releases using the GitHub API
# Usage: GITHUB_TOKEN=your_token ./delete-releases.sh

REPO="thunderkex/revanced-extended"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set"
    echo "Usage: GITHUB_TOKEN=your_token ./delete-releases.sh"
    echo ""
    echo "To create a token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Generate new token (classic)"
    echo "3. Select 'repo' scope"
    echo "4. Copy the token and run:"
    echo "   GITHUB_TOKEN=ghp_xxxxx ./delete-releases.sh"
    exit 1
fi

echo "Fetching releases from $REPO..."

# Function to get all release IDs from a page
get_release_ids() {
    local page=$1
    curl -s -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/releases?per_page=100&page=$page" | \
        python3 -c "import sys, json; releases = json.load(sys.stdin); [print(r['id']) for r in releases]" 2>/dev/null
}

# Function to delete a release by ID
delete_release() {
    local release_id=$1
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/releases/$release_id")
    
    if [ "$response" = "204" ]; then
        echo "✓ Deleted release ID: $release_id"
        return 0
    else
        echo "✗ Failed to delete release ID: $release_id (HTTP $response)"
        return 1
    fi
}

# Collect all release IDs
echo "Collecting release IDs..."
all_ids=()
page=1

while true; do
    ids=$(get_release_ids $page)
    if [ -z "$ids" ]; then
        break
    fi
    
    while IFS= read -r id; do
        all_ids+=("$id")
    done <<< "$ids"
    
    count=$(echo "$ids" | wc -l)
    if [ "$count" -lt 100 ]; then
        break
    fi
    
    ((page++))
done

total=${#all_ids[@]}
echo "Found $total releases to delete"

if [ "$total" -eq 0 ]; then
    echo "No releases found."
    exit 0
fi

echo ""
read -p "Are you sure you want to delete ALL $total releases? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Deleting releases..."

deleted=0
failed=0

for id in "${all_ids[@]}"; do
    if delete_release "$id"; then
        ((deleted++))
    else
        ((failed++))
    fi
    # Small delay to avoid rate limiting
    sleep 0.5
done

echo ""
echo "Done! Deleted: $deleted, Failed: $failed"
