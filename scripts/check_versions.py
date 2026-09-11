#!/usr/bin/env python3
import json, os, sys, urllib.request

CACHE_FILE = "tmp/version_cache.json"

def gh_latest_tag(repo):
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {"User-Agent": "revancex/666"}
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.load(r).get("tag_name", "")
    except Exception:
        return ""

def main():
    os.makedirs("tmp", exist_ok=True)
    cache = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE) as f:
            cache = json.load(f)

    repos = {
        "revanced": "ReVanced/revanced-cli",
        "revanced_extended": "inotia00/revanced-cli",
    }
    changed = []
    for name, repo in repos.items():
        tag = gh_latest_tag(repo)
        if tag and cache.get(name) != tag:
            changed.append(name)
            cache[name] = tag

    with open(CACHE_FILE, "w") as f:
        json.dump(cache, f, indent=2)

    print(",".join(changed) if changed else "none")

if __name__ == "__main__":
    main()
