import requests
import json
import re
import sys
import os
from pathlib import Path
from typing import Dict, Tuple

USERNAME = "thunderkex"  # Change this to your GitHub username
README_PATH = "./README.md"
BUILD_DIR = "./build"

def replace_chunk(content, marker_name, new_content):
    """Replace content between START and END markers"""
    # Handle special case for DOWNLOAD_LINKS which doesn't use START: prefix
    if marker_name == "DOWNLOAD_LINKS":
        start_marker = "<!-- DOWNLOAD_LINKS_START -->"
        end_marker = "<!-- DOWNLOAD_LINKS_END -->"
    else:
        start_marker = f"<!-- START:{marker_name} -->"
        end_marker = f"<!-- END:{marker_name} -->"
    
    pattern = re.compile(
        f"({re.escape(start_marker)})(.*?)({re.escape(end_marker)})",
        re.DOTALL
    )
    
    # For DOWNLOAD_LINKS, the new_content already includes the markers
    if marker_name == "DOWNLOAD_LINKS":
        # Replace everything including markers
        pattern = re.compile(
            f"{re.escape(start_marker)}.*?{re.escape(end_marker)}",
            re.DOTALL
        )
        return pattern.sub(new_content, content)
    else:
        replacement = f"\\1\n{new_content}\n\\3"
        return pattern.sub(replacement, content)

def get_display_name(basename: str) -> str:
    """Map app basenames to display names"""
    display_names = {
        "youtube-ex-revanced": "YouTube Extended",
        "youtube-ex-dev": "YouTube Extended Dev",
        "youtube-ex-morphed": "YouTube Extended Morphed",
        "music-ex-revanced": "YouTube Music Extended",
        "music-ex-dev": "YouTube Music Extended Dev",
        "music-ex-morphed": "YouTube Music Morphed",
        "reddit-ex": "Reddit Extended",
        "facebook": "Facebook",
        "instagram": "Instagram",
        "spotify": "Spotify",
        "soundcloud": "SoundCloud",
        "gphotos": "Google Photos",
        "lightroom": "Lightroom",
        "x-piko": "X/Twitter (Piko)",
        "x-piko-dev": "X/Twitter (Piko Dev)",
        "tiktok": "TikTok",
    }
    return display_names.get(basename, basename)

def extract_existing_links(content: str, category: str) -> Dict[str, Tuple[str, str]]:
    """Extract existing download links from README for a specific category"""
    links = {}
    lines = content.split('\n')
    
    in_section = False
    in_table = False
    
    for line in lines:
        # Check if we're entering the category section
        if f"### {category}" in line:
            in_section = True
            continue
        
        # Check if we've left the section
        if in_section and line.startswith("###") and category not in line:
            break
        
        # Check for table header
        if in_section and "| App " in line and "Magisk Module" in line:
            in_table = True
            continue
        
        # Parse table rows
        if in_section and in_table and line.startswith("| **"):
            # Extract app name
            app_match = re.search(r'\*\*([^*]+)\*\*', line)
            if not app_match:
                continue
            
            app_name = app_match.group(1)
            
            # Extract URLs
            magisk_match = re.search(r'\]\((https://github\.com/[^)]+\.zip)\)', line)
            apk_match = re.search(r'\.zip\).*?\]\((https://github\.com/[^)]+\.apk)\)', line)
            
            if magisk_match and apk_match:
                # Map display name back to basename
                basename_map = {
                    "YouTube Extended": "youtube-ex-revanced",
                    "YouTube Extended Dev": "youtube-ex-dev",
                    "YouTube Extended Morphed": "youtube-ex-morphed",
                    "YouTube Music Extended": "music-ex-revanced",
                    "YouTube Music Extended Dev": "music-ex-dev",
                    "YouTube Music Morphed": "music-ex-morphed",
                    "Reddit Extended": "reddit-ex",
                    "Facebook": "facebook",
                    "Instagram": "instagram",
                    "Spotify": "spotify",
                    "SoundCloud": "soundcloud",
                    "Google Photos": "gphotos",
                    "Lightroom": "lightroom",
                    "X/Twitter (Piko)": "x-piko",
                    "X/Twitter (Piko Dev)": "x-piko-dev",
                    "TikTok": "tiktok",
                }
                basename = basename_map.get(app_name)
                if basename:
                    links[basename] = (magisk_match.group(1), apk_match.group(1))
    
    return links

def update_download_links():
    """Update download links in README from built files"""
    release_tag = os.getenv('RELEASE_TAG', 'latest')
    github_repo = os.getenv('GITHUB_REPOSITORY', 'thunderkex/revanced-extended')
    
    build_path = Path(BUILD_DIR)
    if not build_path.exists():
        print(f"Build directory {BUILD_DIR} not found, skipping download links update")
        return None
    
    # Read current README
    with open(README_PATH, 'r', encoding='utf-8') as f:
        readme_content = f.read()
    
    # Initialize category dictionaries
    youtube_apps = {}
    music_apps = {}
    social_apps = {}
    media_apps = {}
    photo_apps = {}
    
    # Extract existing links from all categories
    for category, apps_dict in [
        ("🎬 YouTube Apps", youtube_apps),
        ("🎵 YouTube Music Apps", music_apps),
        ("🐦 Social Media Apps", social_apps),
        ("🎶 Music & Media Apps", media_apps),
        ("📸 Photo & Creative Apps", photo_apps),
    ]:
        existing_links = extract_existing_links(readme_content, category)
        for basename, (magisk_url, apk_url) in existing_links.items():
            magisk_badge = f"[![Download](https://img.shields.io/badge/Download-Magisk-00C853?style=for-the-badge&logo=android)]({magisk_url})"
            apk_badge = f"[![Download](https://img.shields.io/badge/Download-APK-FF6F00?style=for-the-badge&logo=android)]({apk_url})"
            apps_dict[basename] = (magisk_badge, apk_badge)
    
    # Process newly built files
    built_files = {}
    for file_path in build_path.glob('*'):
        if file_path.suffix not in ['.zip', '.apk']:
            continue
        
        filename = file_path.name
        # Extract basename
        basename = re.sub(r'-revanced-magisk.*|-revanced.*', '', filename)
        
        dl_url = f"https://github.com/{github_repo}/releases/download/{release_tag}/{filename}"
        badge = f"[![Download](https://img.shields.io/badge/Download-{'Magisk' if filename.endswith('.zip') else 'APK'}-{'00C853' if filename.endswith('.zip') else 'FF6F00'}?style=for-the-badge&logo=android)]({dl_url})"
        
        if basename not in built_files:
            built_files[basename] = {}
        
        if filename.endswith('.zip'):
            built_files[basename]['magisk'] = badge
        else:
            built_files[basename]['apk'] = badge
    
    # Update categories with newly built files
    for basename, badges in built_files.items():
        if 'magisk' in badges and 'apk' in badges:
            entry = (badges['magisk'], badges['apk'])
            
            if basename.startswith('youtube-ex'):
                youtube_apps[basename] = entry
            elif basename.startswith('music-ex'):
                music_apps[basename] = entry
            elif basename in ['reddit-ex', 'facebook', 'instagram'] or basename.startswith('x-piko'):
                social_apps[basename] = entry
            elif basename in ['spotify', 'soundcloud', 'tiktok']:
                media_apps[basename] = entry
            elif basename in ['gphotos', 'lightroom']:
                photo_apps[basename] = entry
    
    # Generate markdown
    from datetime import datetime
    lines = []
    lines.append("<!-- DOWNLOAD_LINKS_START -->")
    lines.append(f"*📅 Last updated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')} | Release: [{release_tag}](https://github.com/{github_repo}/releases/tag/{release_tag})*")
    lines.append("")
    
    # Helper function to add category section
    def add_category(title: str, apps_dict: Dict, app_order: list):
        if not apps_dict:
            return
        
        lines.append(f"### {title}")
        lines.append("| App | 📦 Magisk Module | 📱 APK |")
        lines.append("|-----|------------------|--------|")
        
        for app in app_order:
            if app in apps_dict:
                magisk_badge, apk_badge = apps_dict[app]
                lines.append(f"| **{get_display_name(app)}** | {magisk_badge} | {apk_badge} |")
        
        lines.append("")
    
    # Add all categories
    add_category("🎬 YouTube Apps", youtube_apps, 
                 ["youtube-ex-revanced", "youtube-ex-dev", "youtube-ex-morphed"])
    add_category("🎵 YouTube Music Apps", music_apps,
                 ["music-ex-revanced", "music-ex-dev", "music-ex-morphed"])
    add_category("🐦 Social Media Apps", social_apps,
                 ["reddit-ex", "facebook", "instagram", "x-piko", "x-piko-dev"])
    add_category("🎶 Music & Media Apps", media_apps,
                 ["spotify", "soundcloud", "tiktok"])
    add_category("📸 Photo & Creative Apps", photo_apps,
                 ["gphotos", "lightroom"])
    
    lines.append("<!-- DOWNLOAD_LINKS_END -->")
    
    return '\n'.join(lines)

def main():
    try:
        with open(README_PATH, 'r', encoding='utf-8') as f:
            content = f.read()

        if "<!-- DOWNLOAD_LINKS_START -->" in content:
            print("Updating Download Links...")
            download_links = update_download_links()
            if download_links:
                content = replace_chunk(content, "DOWNLOAD_LINKS", download_links)
            else:
                print("Skipping download links update (no build directory)")

        with open(README_PATH, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("README updated successfully.")

    except Exception as e:
        print(f"Error updating README: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
